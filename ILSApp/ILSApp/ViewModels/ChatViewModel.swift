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
    @Published var streamTokenCount: Int = 0
    @Published var streamElapsedSeconds: Double = 0
    @Published var pendingPermissionRequest: PermissionRequest?
    private var streamStartTime: Date?

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

    // MARK: - Shared Decoder
    // nonisolated: JSONDecoder is thread-safe for decoding. Isolated to instance lifetime.
    nonisolated private let jsonDecoder = JSONDecoder()

    // MARK: - Batching Properties
    private var pendingStreamMessages: [StreamMessage] = []
    private var batchTask: Task<Void, Never>?
    private let batchInterval: TimeInterval = 0.075
    private var lastProcessedMessageIndex = 0

    init() {}

    func configure(client: APIClient, sseClient: SSEClient) {
        self.apiClient = client
        self.sseClient = sseClient
        setupBindings()
    }

    deinit {
        batchTask?.cancel()
        connectingTimer?.cancel()
        cancellables.removeAll()
    }

    private func setupBindings() {
        guard let sseClient else { return }

        sseClient.$isStreaming
            .sink { [weak self] streaming in
                guard let self = self else { return }
                self.isStreaming = streaming

                if streaming {
                    // Reset streaming stats
                    self.streamTokenCount = 0
                    self.streamElapsedSeconds = 0
                    self.streamStartTime = Date()
                } else {
                    // Streaming ended - flush remaining messages and stop timer
                    self.flushPendingMessages()
                    self.stopBatchTimer()
                    self.lastProcessedMessageIndex = 0
                    self.streamStartTime = nil
                }
            }
            .store(in: &cancellables)

        sseClient.$error
            .assign(to: &$error)

        sseClient.$connectionState
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
        guard batchTask == nil else { return }

        batchTask = Task { [weak self] in
            let intervalNanos = UInt64((self?.batchInterval ?? 0.075) * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                guard !Task.isCancelled else { break }
                self?.flushPendingMessages()
            }
        }
    }

    /// Stop the batch timer
    private func stopBatchTimer() {
        batchTask?.cancel()
        batchTask = nil
    }

    private func startConnectingTimer() {
        connectingTimer?.cancel()
        connectingTooLong = false
        connectingTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.connectingTooLong = true
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
            // For new sessions, a 404 just means no messages yet — show welcome, not error
            let isNotFound = (error as? APIError)?.isNotFound == true
            if !isNotFound {
                self.error = error
            }
            AppLogger.shared.error("Failed to load message history: \(error)", category: "chat")
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

    /// Reload messages on foreground return, preserving any in-progress stream
    func refreshMessages() async {
        guard !isStreaming else { return } // Don't interrupt active streams
        await loadMessageHistory()
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

    /// Parse tool calls JSON string into ToolCallDisplay array
    private func parseToolCalls(from jsonString: String?) -> [ToolCallDisplay] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let blocks = try jsonDecoder.decode([ToolUseBlock].self, from: data)
            return blocks.map { block in
                ToolCallDisplay(id: block.id, name: block.name, inputPreview: nil)
            }
        } catch {
            AppLogger.shared.error("Failed to parse tool calls: \(error)", category: "chat")
            return []
        }
    }

    /// Parse tool results JSON string into ToolResultDisplay array
    private func parseToolResults(from jsonString: String?) -> [ToolResultDisplay] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let blocks = try jsonDecoder.decode([ToolResultBlock].self, from: data)
            return blocks.map { block in
                ToolResultDisplay(toolUseId: block.toolUseId, content: block.content, isError: block.isError)
            }
        } catch {
            AppLogger.shared.error("Failed to parse tool results: \(error)", category: "chat")
            return []
        }
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(isUser: true, text: text))
    }

    func sendMessage(prompt: String, projectId: UUID?, options: ChatOptions? = nil) {
        guard let sseClient else { return }
        let request = ChatStreamRequest(
            prompt: prompt,
            sessionId: sessionId,
            projectId: projectId,
            options: options
        )

        sseClient.startStream(request: request)
    }

    /// Retry by removing the assistant response and resending the preceding user message
    func retryMessage(_ message: ChatMessage, projectId: UUID?) {
        guard !message.isUser else { return }
        // Find the index of this assistant message
        guard let assistantIndex = messages.firstIndex(where: { $0.id == message.id }) else { return }
        // Find the preceding user message
        let precedingUserMessage = messages[..<assistantIndex].last(where: { $0.isUser })
        // Remove the assistant message
        messages = messages.filter { $0.id != message.id }
        // Resend if we found a user message
        if let userMessage = precedingUserMessage {
            sendMessage(prompt: userMessage.text, projectId: projectId)
        }
    }

    /// Delete a message from the local messages array
    func deleteMessage(_ message: ChatMessage) {
        messages = messages.filter { $0.id != message.id }
    }

    func cancel() {
        // Notify backend to kill Claude CLI process (best-effort, fire-and-forget)
        if let sessionId = sessionId, let apiClient = apiClient {
            Task {
                do {
                    let _: APIResponse<DeletedResponse> = try await apiClient.post("/chat/cancel/\(sessionId.uuidString)", body: EmptyBody())
                } catch {
                    // Cancel is best-effort — don't surface errors to user
                    AppLogger.shared.warning("Backend cancel failed (non-fatal): \(error)", category: "chat")
                }
            }
        }
        sseClient?.cancel()
    }

    /// Respond to a pending permission request (allow/deny)
    ///
    /// Sends the decision to the backend which forwards it to the Claude CLI process via stdin.
    /// Route: POST /chat/permission/{sessionId}/{requestId}
    func respondToPermission(requestId: String, decision: String) {
        guard let apiClient, let sessionId else { return }
        pendingPermissionRequest = nil

        Task {
            do {
                let body = PermissionDecision(decision: decision)
                let _: APIResponse<AcknowledgedResponse> = try await apiClient.post(
                    "/chat/permission/\(sessionId.uuidString)/\(requestId)",
                    body: body
                )
            } catch {
                AppLogger.shared.warning("Permission response failed (non-fatal): \(error)", category: "chat")
            }
        }
    }

    /// Fork the current session
    func forkSession() async -> ChatSession? {
        guard let sessionId = sessionId, let apiClient else { return nil }

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions/\(sessionId.uuidString)/fork", body: EmptyBody())
            return response.data
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to fork session: \(error)", category: "chat")
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
                AppLogger.shared.info("Session initialized: \(sysMsg.data.sessionId)", category: "chat")

            case .assistant(let assistantMsg):
                handleAssistantMessage(assistantMsg, message: &currentMessage)

            case .result(let resultMsg):
                currentMessage.cost = resultMsg.totalCostUSD

            case .permission(let permissionReq):
                pendingPermissionRequest = permissionReq

            case .user(let userMsg):
                handleUserMessage(userMsg, message: &currentMessage)

            case .streamEvent(let event):
                handleStreamEvent(event, message: &currentMessage)

            case .error(let errorMsg):
                currentMessage.text += "\n\nError: \(errorMsg.message)"
            }
        }

        // Update streaming stats
        if let startTime = streamStartTime {
            streamElapsedSeconds = Date().timeIntervalSince(startTime)
        }
        // Approximate token count from text length (rough: ~4 chars per token)
        streamTokenCount = max(streamTokenCount, currentMessage.text.count / 4)

        messages.append(currentMessage)
    }

    // MARK: - Stream Message Handlers

    /// Handle assistant message: accumulate text, tool calls, tool results, and thinking blocks.
    private func handleAssistantMessage(_ assistantMsg: AssistantMessage, message: inout ChatMessage) {
        for block in assistantMsg.content {
            switch block {
            case .text(let textBlock):
                message.text += textBlock.text

            case .toolUse(let toolUseBlock):
                message.toolCalls.append(ToolCallDisplay(
                    id: toolUseBlock.id,
                    name: toolUseBlock.name,
                    inputPreview: nil
                ))

            case .toolResult(let resultBlock):
                message.toolResults.append(ToolResultDisplay(
                    toolUseId: resultBlock.toolUseId,
                    content: resultBlock.content,
                    isError: resultBlock.isError
                ))

            case .thinking(let thinkingBlock):
                message.thinking = thinkingBlock.thinking
            }
        }
    }

    /// Handle user message: accumulate tool results from user content blocks.
    private func handleUserMessage(_ userMsg: UserMessage, message: inout ChatMessage) {
        for block in userMsg.content {
            switch block {
            case .toolResult(let resultBlock):
                message.toolResults.append(ToolResultDisplay(
                    toolUseId: resultBlock.toolUseId,
                    content: resultBlock.content,
                    isError: resultBlock.isError
                ))
            default:
                break
            }
        }
    }

    /// Handle stream event: append character-by-character deltas for text, JSON, and thinking.
    private func handleStreamEvent(_ event: StreamEventMessage, message: inout ChatMessage) {
        guard let delta = event.delta else { return }

        switch delta {
        case .textDelta(let text):
            message.text += text

        case .inputJsonDelta(let json):
            // Accumulate partial JSON on last tool call's inputPreview
            if !message.toolCalls.isEmpty {
                let lastIndex = message.toolCalls.count - 1
                let existing = message.toolCalls[lastIndex].inputPreview ?? ""
                message.toolCalls[lastIndex].inputPreview = existing + json
            }

        case .thinkingDelta(let thinking):
            message.thinking = (message.thinking ?? "") + thinking
        }
    }
}
