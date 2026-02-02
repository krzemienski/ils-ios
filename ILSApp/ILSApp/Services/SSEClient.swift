import Foundation
import Combine
import ILSShared

/// Server-Sent Events client for streaming chat responses
@MainActor
class SSEClient: ObservableObject {
    @Published var messages: [StreamMessage] = []
    @Published var isStreaming: Bool = false
    @Published var error: Error?

    private var task: URLSessionDataTask?
    private let baseURL: String

    init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL
    }

    /// Start streaming a chat request
    func startStream(request: ChatStreamRequest) {
        guard !isStreaming else { return }

        isStreaming = true
        messages = []
        error = nil

        Task {
            await performStream(request: request)
        }
    }

    private func performStream(request: ChatStreamRequest) async {
        let url = URL(string: "\(baseURL)/api/v1/chat/stream")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            self.error = error
            self.isStreaming = false
            return
        }

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            var currentEvent = ""
            var currentData = ""

            for try await line in asyncBytes.lines {
                if line.hasPrefix("event:") {
                    currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    currentData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                    if !currentData.isEmpty {
                        await parseAndAddMessage(event: currentEvent, data: currentData)
                    }

                    currentEvent = ""
                    currentData = ""
                }
            }
        } catch {
            self.error = error
        }

        isStreaming = false
    }

    private func parseAndAddMessage(event: String, data: String) async {
        guard let jsonData = data.data(using: .utf8) else { return }

        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(StreamMessage.self, from: jsonData)
            messages.append(message)
        } catch {
            print("Failed to parse SSE message: \(error)")
        }
    }

    /// Cancel the current stream
    func cancel() {
        task?.cancel()
        task = nil
        isStreaming = false
    }
}

// MARK: - Chat Request

struct ChatStreamRequest: Encodable {
    let prompt: String
    let sessionId: UUID?
    let projectId: UUID?
    let options: ChatOptions?
}

struct ChatOptions: Encodable {
    let model: String?
    let permissionMode: String?
    let maxTurns: Int?
}
