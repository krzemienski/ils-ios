import Foundation
import ILSShared

@MainActor
final class SSHViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var platform: String?
    @Published var connectionError: String?
    @Published var status: SSHStatusResponse?

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func connect(host: String, port: Int, username: String, authMethod: String, credential: String) async {
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        do {
            let request = SSHConnectRequest(host: host, port: port, username: username, authMethod: authMethod, credential: credential)
            let wrapper: APIResponse<ConnectionResponse> = try await apiClient.post("/ssh/connect", body: request)
            let response = wrapper.data
            isConnected = response?.success ?? false
            if response?.success != true { connectionError = response?.error ?? "Unknown error" }
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func disconnect() async {
        let _: APIResponse<AcknowledgedResponse>? = try? await apiClient.post("/ssh/disconnect", body: EmptyBody())
        isConnected = false
        platform = nil
    }

    func detectPlatform() async -> SSHPlatformResponse? {
        let wrapper: APIResponse<SSHPlatformResponse>? = try? await apiClient.get("/ssh/platform")
        let response = wrapper?.data
        platform = response?.platform
        return response
    }

    func refreshStatus() async {
        let wrapper: APIResponse<SSHStatusResponse>? = try? await apiClient.get("/ssh/status")
        status = wrapper?.data
        isConnected = status?.connected ?? false
        platform = status?.platform
    }
}
