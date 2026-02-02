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
            return "Connecting..."
        case .connected:
            return isStreaming ? "Claude is responding..." : nil
        case .reconnecting(let attempt):
            return "Reconnecting (attempt \(attempt)/3)..."
        }
    }

    var sessionId: UUID?

    private let sseClient = SSEClient()
    private let apiClient = APIClient()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        sseClient.$isStreaming
            .receive(on: DispatchQueue.main)
            .assign(to: &$isStreaming)

        sseClient.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        sseClient.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        sseClient.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] streamMessages in
                self?.processStreamMessages(streamMessages)
            }
            .store(in: &cancellables)
    }

    /// Load message history for the current session from the backend
    func loadMessageHistory() async {
        guard let sessionId = sessionId else { return }

        isLoadingHistory = true
        error = nil

        do {
            let response: APIResponse<ListResponse<Message>> = try await apiClient.get("/sessions/\(sessionId.uuidString)/messages")

            if let data = response.data {
                // Convert backend Messages to local ChatMessages
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

                // Replace messages with loaded history
                messages = loadedMessages

                // Show welcome message for empty sessions
                if messages.isEmpty {
                    showWelcomeMessage()
                }
            }
        } catch {
            self.error = error
            print("Failed to load message history: \(error)")
            // Show welcome message on error as fallback for new sessions
            if messages.isEmpty {
                showWelcomeMessage()
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
        let request = ChatStreamRequest(
            prompt: prompt,
            sessionId: sessionId,
            projectId: projectId,
            options: nil
        )

        sseClient.startStream(request: request)
    }

    func cancel() {
        sseClient.cancel()
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
