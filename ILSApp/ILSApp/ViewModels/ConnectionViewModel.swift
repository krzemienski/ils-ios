import Foundation
import Combine

/// ViewModel for managing backend server connection testing and status
@MainActor
class ConnectionViewModel: ObservableObject {
    @Published var isTestingConnection = false
    @Published var error: Error?
    @Published var lastConnectionError: String?

    private let client: APIClient

    init(baseURL: String = "http://localhost:8080") {
        self.client = APIClient(baseURL: baseURL)
    }

    /// Test connection to the backend server
    /// - Parameter serverURL: The server URL to test (e.g., "http://localhost:8080")
    /// - Returns: True if connection successful, false otherwise
    @discardableResult
    func testConnection(serverURL: String) async -> Bool {
        isTestingConnection = true
        error = nil
        lastConnectionError = nil

        defer { isTestingConnection = false }

        do {
            let client = APIClient(baseURL: serverURL)
            _ = try await client.healthCheck()
            return true
        } catch let urlError as URLError {
            // Convert URLError to specific connection error messages
            let errorMessage = mapURLError(urlError)
            lastConnectionError = errorMessage
            error = urlError
            return false
        } catch {
            // Handle other errors
            lastConnectionError = "Connection failed: \(error.localizedDescription)"
            self.error = error
            return false
        }
    }

    /// Map URLError to user-friendly connection error messages
    private func mapURLError(_ error: URLError) -> String {
        switch error.code {
        case .cannotFindHost:
            return "Cannot find host. Please check the server address."
        case .cannotConnectToHost:
            return "Cannot connect to server. Make sure the backend is running."
        case .timedOut:
            return "Connection timed out. The server is not responding."
        case .unsupportedURL:
            return "Invalid URL format. Please check the server address."
        case .notConnectedToInternet:
            return "No internet connection available."
        case .networkConnectionLost:
            return "Network connection was lost. Please try again."
        case .badURL:
            return "Invalid URL. Please check the server address format."
        default:
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}
