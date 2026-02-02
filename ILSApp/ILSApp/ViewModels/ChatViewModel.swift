import Foundation
import Combine
import ILSShared

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
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
        if let lastMessage = messages.last, !lastMessage.isUser {
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
