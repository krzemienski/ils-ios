import Foundation
import Combine
import ILSShared

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var isLoadingHistory = false
    @Published var error: Error?
    @Published var connectionState: SSEClient.ConnectionState = .disconnected
    @Published var connectingTooLong = false

    /// Computed property for current assistant message being streamed
    var currentStreamingMessage: ChatMessage? {
        guard isStreaming, let lastMessage = messages.last, !lastMessage.isUser else {
            return nil
        }
        return lastMessage
    }

    /// Human-readable status text for connection state
    var statusText: String? {
        if isLoadingHistory {
            return "Loading history..."
        }
        switch connectionState {
        case .disconnected:
            return nil
        case .connecting:
            return connectingTooLong ? "Taking longer than expected..." : "Connecting..."
        case .connected:
            return isStreaming ? "Claude is responding..." : nil
        case .reconnecting(let attempt):
            return "Reconnecting (attempt \(attempt)/3)..."
        }
    }

    var sessionId: UUID?
    /// For external sessions: the encoded project path (e.g. "-Users-nick-Desktop-project")
    var encodedProjectPath: String?
    /// For external sessions: the claude session ID string
    var claudeSessionId: String?

    private var sseClient: SSEClient?
    private var apiClient: APIClient?
    private var cancellables = Set<AnyCancellable>()
    private var connectingTimer: Task<Void, Never>?

    // MARK: - Batching Properties
    private var pendingStreamMessages: [StreamMessage] = []
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.075
    private var lastProcessedMessageIndex = 0

    init() {}

    func configure(client: APIClient, sseClient: SSEClient) {
        self.apiClient = client
        self.sseClient = sseClient
        setupBindings()
    }

    deinit {
        batchTimer?.invalidate()
        connectingTimer?.cancel()
    }

    private func setupBindings() {
        guard let sseClient else { return }

        sseClient.$isStreaming
            .receive(on: DispatchQueue.main)
            .sink { [weak self] streaming in
                guard let self = self else { return }
                self.isStreaming = streaming

                // Manage timer lifecycle based on streaming state
                if !streaming {
                    // Streaming ended - flush remaining messages and stop timer
                    self.flushPendingMessages()
                    self.stopBatchTimer()
                    // Reset index tracker for next stream
                    self.lastProcessedMessageIndex = 0
                }
            }
            .store(in: &cancellables)

        sseClient.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        sseClient.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.connectionState = state
                if case .connecting = state {
                    self.startConnectingTimer()
                } else {
                    self.connectingTimer?.cancel()
                    self.connectingTimer = nil
                    self.connectingTooLong = false
                }
            }
            .store(in: &cancellables)

        sseClient.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] streamMessages in
                guard let self = self else { return }

                // Only process NEW messages since last index
                let newMessages = Array(streamMessages.dropFirst(self.lastProcessedMessageIndex))
                if !newMessages.isEmpty {
                    // Accumulate only new messages in pending buffer
                    self.pendingStreamMessages.append(contentsOf: newMessages)
                    self.lastProcessedMessageIndex = streamMessages.count

                    // Start batch timer if not already running
                    self.startBatchTimer()
                }
            }
            .store(in: &cancellables)
    }

    /// Start the batch timer to flush pending messages at regular intervals
    private func startBatchTimer() {
        guard batchTimer == nil else { return }

        batchTimer = Timer.scheduledTimer(
            withTimeInterval: batchInterval,
            repeats: true
        ) { [weak self] _ in
            self?.flushPendingMessages()
        }
    }

    /// Stop the batch timer
    private func stopBatchTimer() {
        batchTimer?.invalidate()
        batchTimer = nil
    }

    private func startConnectingTimer() {
        connectingTimer?.cancel()
        connectingTooLong = false
        connectingTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self.connectingTooLong = true
        }
    }

    /// Flush pending messages to UI immediately
    private func flushPendingMessages() {
        guard !pendingStreamMessages.isEmpty else { return }

        let messagesToProcess = pendingStreamMessages
        pendingStreamMessages.removeAll()

        processStreamMessages(messagesToProcess)
    }

    /// Load message history for the current session from the backend
    func loadMessageHistory() async {
        guard let apiClient else { return }

        isLoadingHistory = true
        error = nil

        do {
            // Branch: external sessions load from JSONL transcript, ILS sessions from DB
            if let encodedProjectPath = encodedProjectPath, let claudeSessionId = claudeSessionId {
                let path = "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)"
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get(path)

                if let data = response.data {
                    let loadedMessages = data.items.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }
                    messages = loadedMessages

                    if messages.isEmpty {
                        showEmptyTranscriptMessage()
                    }
                }
            } else if let sessionId = sessionId {
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get("/sessions/\(sessionId.uuidString)/messages")

                if let data = response.data {
                    let loadedMessages = data.items.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            toolResults: parseToolResults(from: message.toolResults),
                            thinking: nil,
                            cost: nil,
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }

                    messages = loadedMessages

                    if messages.isEmpty {
                        showWelcomeMessage()
                    }
                }
            }
        } catch {
            self.error = error
            print("Failed to load message history: \(error)")
            if messages.isEmpty {
                if encodedProjectPath != nil {
                    showEmptyTranscriptMessage()
                } else {
                    showWelcomeMessage()
                }
            }
        }

        isLoadingHistory = false
    }

    /// Display a welcome message for new/empty sessions
    private func showWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            isUser: false,
            text: "Hello! I'm Claude, your AI assistant. How can I help you today?",
            isFromHistory: true
        )
        messages = [welcomeMessage]
    }

    /// Display message when transcript has no readable messages
    private func showEmptyTranscriptMessage() {
        let emptyMessage = ChatMessage(
            isUser: false,
            text: "This session transcript contains no readable messages.",
            isFromHistory: true
        )
        messages = [emptyMessage]
    }

    /// Parse tool calls JSON string into ToolCall array
    private func parseToolCalls(from jsonString: String?) -> [ToolCall] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            let blocks = try decoder.decode([ToolUseBlock].self, from: data)
            return blocks.map { block in
                ToolCall(id: block.id, name: block.name, inputPreview: nil)
            }
        } catch {
            print("Failed to parse tool calls: \(error)")
            return []
        }
    }

    /// Parse tool results JSON string into ToolResult array
    private func parseToolResults(from jsonString: String?) -> [ToolResult] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            let blocks = try decoder.decode([ToolResultBlock].self, from: data)
            return blocks.map { block in
                ToolResult(toolUseId: block.toolUseId, content: block.content, isError: block.isError)
            }
        } catch {
            print("Failed to parse tool results: \(error)")
            return []
        }
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(isUser: true, text: text))
    }

    func sendMessage(prompt: String, projectId: UUID?) {
        guard let sseClient else { return }
        let request = ChatStreamRequest(
            prompt: prompt,
            sessionId: sessionId,
            projectId: projectId,
            options: nil
        )

        sseClient.startStream(request: request)
    }

    func cancel() {
        sseClient?.cancel()
    }

    /// Fork the current session
    func forkSession() async -> ChatSession? {
        guard let sessionId = sessionId, let apiClient else { return nil }

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions/\(sessionId.uuidString)/fork", body: EmptyBody())
            return response.data
        } catch {
            self.error = error
            print("Failed to fork session: \(error)")
            return nil
        }
    }

    private func processStreamMessages(_ streamMessages: [StreamMessage]) {
        // Find or create current assistant message
        var currentMessage: ChatMessage
        if let lastMessage = messages.last, !lastMessage.isUser, !lastMessage.isFromHistory {
            currentMessage = lastMessage
            messages.removeLast()
        } else {
            currentMessage = ChatMessage(isUser: false, text: "")
        }

        for streamMessage in streamMessages {
            switch streamMessage {
            case .system(let sysMsg):
                // Could update session ID from init
                print("Session initialized: \(sysMsg.data.sessionId)")

            case .assistant(let assistantMsg):
                for block in assistantMsg.content {
                    switch block {
                    case .text(let textBlock):
                        currentMessage.text += textBlock.text

                    case .toolUse(let toolUseBlock):
                        currentMessage.toolCalls.append(ToolCall(
                            id: toolUseBlock.id,
                            name: toolUseBlock.name,
                            inputPreview: nil
                        ))

                    case .toolResult(let resultBlock):
                        currentMessage.toolResults.append(ToolResult(
                            toolUseId: resultBlock.toolUseId,
                            content: resultBlock.content,
                            isError: resultBlock.isError
                        ))

                    case .thinking(let thinkingBlock):
                        currentMessage.thinking = thinkingBlock.thinking
                    }
                }

            case .result(let resultMsg):
                currentMessage.cost = resultMsg.totalCostUSD

            case .permission:
                // Handle permission requests
                break

            case .error(let errorMsg):
                currentMessage.text += "\n\nError: \(errorMsg.message)"
            }
        }

        messages.append(currentMessage)
    }
}
