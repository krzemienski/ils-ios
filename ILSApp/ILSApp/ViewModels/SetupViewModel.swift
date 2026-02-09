import Foundation
import ILSShared

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var steps: [SetupProgress] = []
    @Published var isRunning = false
    @Published var isComplete = false
    @Published var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func startSetup(request: StartSetupRequest) async {
        isRunning = true
        isComplete = false
        error = nil
        steps = SetupProgress.SetupStep.allCases.map {
            SetupProgress(step: $0, status: .pending, message: "Waiting...")
        }

        do {
            let baseURL = apiClient.baseURL
            guard let url = URL(string: "\(baseURL)/api/v1/setup/start") else {
                self.error = "Invalid server URL"
                isRunning = false
                return
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                self.error = "Setup request failed"
                isRunning = false
                return
            }

            // Parse SSE stream for real-time progress updates
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))
                guard let data = jsonString.data(using: .utf8) else { continue }

                if let progress = try? JSONDecoder().decode(SetupProgress.self, from: data) {
                    if let idx = steps.firstIndex(where: { $0.step == progress.step }) {
                        steps[idx] = progress
                    }
                    if progress.status == .failure {
                        self.error = progress.message
                        isRunning = false
                        return
                    }
                }
            }

            isComplete = true
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
    }
}
