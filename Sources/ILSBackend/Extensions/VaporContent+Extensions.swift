import Vapor
import ILSShared

// MARK: - Vapor Content Conformance for ILSShared DTOs
// These extensions allow shared DTOs to be used as Vapor request/response types

// Generic wrappers need explicit conformance to all Content requirements
extension APIResponse: AsyncResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
}

extension APIResponse: ResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        do {
            try response.content.encode(self)
            return request.eventLoop.makeSucceededFuture(response)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension APIResponse: RequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Self> {
        do {
            let decoded = try request.content.decode(Self.self)
            return request.eventLoop.makeSucceededFuture(decoded)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension APIResponse: AsyncRequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) async throws -> Self {
        try request.content.decode(Self.self)
    }
}

extension APIResponse: Content where T: Content {}
extension APIResponse: @unchecked Sendable where T: Sendable {}

// ListResponse conformances
extension ListResponse: AsyncResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
}

extension ListResponse: ResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        do {
            try response.content.encode(self)
            return request.eventLoop.makeSucceededFuture(response)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension ListResponse: RequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Self> {
        do {
            let decoded = try request.content.decode(Self.self)
            return request.eventLoop.makeSucceededFuture(decoded)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension ListResponse: AsyncRequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) async throws -> Self {
        try request.content.decode(Self.self)
    }
}

extension ListResponse: Content where T: Content {}
extension ListResponse: @unchecked Sendable where T: Sendable {}

// PaginatedResponse conformances
extension PaginatedResponse: AsyncResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
}

extension PaginatedResponse: ResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        do {
            try response.content.encode(self)
            return request.eventLoop.makeSucceededFuture(response)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension PaginatedResponse: RequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) -> EventLoopFuture<Self> {
        do {
            let decoded = try request.content.decode(Self.self)
            return request.eventLoop.makeSucceededFuture(decoded)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

extension PaginatedResponse: AsyncRequestDecodable where T: Content {
    public static func decodeRequest(_ request: Request) async throws -> Self {
        try request.content.decode(Self.self)
    }
}

extension PaginatedResponse: Content where T: Content {}
extension PaginatedResponse: @unchecked Sendable where T: Sendable {}

// MARK: - Request Types
extension CreateProjectRequest: Content {}
extension UpdateProjectRequest: Content {}
extension CreateSessionRequest: Content {}
extension SessionScanResponse: Content {}
extension RecentSessionsResponse: Content {}
extension ChatStreamRequest: Content {}
extension ChatOptions: Content {}
extension PermissionDecision: Content {}
extension CreateSkillRequest: Content {}
extension UpdateSkillRequest: Content {}
extension CreateMCPRequest: Content {}
extension InstallPluginRequest: Content {}
extension SkillInstallRequest: Content {}
extension UpdateConfigRequest: Content {}

// MARK: - GitHub Search Types
extension GitHubSearchResult: Content {}
extension GitHubCodeSearchResponse: Content {}
extension GitHubCodeItem: Content {}
extension GitHubRepository: Content {}
extension PluginSearchResult: Content {}
extension AddMarketplaceRequest: Content {}
extension Marketplace: Content {}
extension ValidateConfigRequest: Content {}

// MARK: - Response Types
extension ConfigValidationResult: Content {}
extension StatsResponse: Content {}
extension CountStat: Content {}
extension SessionStat: Content {}
extension MCPStat: Content {}
extension PluginStat: Content {}
extension DeletedResponse: Content {}
extension AcknowledgedResponse: Content {}
extension CancelledResponse: Content {}
extension EnabledResponse: Content {}
extension ConnectionResponse: Content {}
extension ServerInfo: Content {}
extension ClaudeConfigPaths: Content {}
extension ServerStatus: Content {}
// ConnectRequest removed — consolidated into SSHConnectRequest

// MARK: - Model Types
extension Project: Content {}
extension ChatSession: Content {}
extension Message: Content {}
extension MessageRole: Content {}
extension ExternalSession: Content {}
extension Skill: Content {}
extension Plugin: Content {}
extension PluginMarketplace: Content {}
extension PluginInfo: Content {}
extension MCPServer: Content {}
extension ClaudeConfig: Content {}
extension PermissionsConfig: Content {}
extension HooksConfig: Content {}
extension HookDefinition: Content {}
extension ConfigInfo: Content {}

// MARK: - Stream Types
extension StreamMessage: Content {}
extension SystemMessage: Content {}
extension SystemData: Content {}
extension AssistantMessage: Content {}
extension ContentBlock: Content {}
extension TextBlock: Content {}
extension ToolUseBlock: Content {}
extension ToolResultBlock: Content {}
extension ThinkingBlock: Content {}
extension ResultMessage: Content {}
extension UsageInfo: Content {}
extension PermissionRequest: Content {}
extension StreamError: Content {}
extension AnyCodable: Content {}

// MARK: - Phase 3: SSH & Fleet Types
extension FleetHost: Content {}
extension FleetHost.HealthStatus: Content {}
extension SetupProgress: Content {}
extension SetupProgress.SetupStep: Content {}
extension SetupProgress.StepStatus: Content {}
extension SSHConnectRequest: Content {}
extension SSHExecuteRequest: Content {}
extension SSHStatusResponse: Content {}
extension SSHExecuteResponse: Content {}
extension SSHPlatformResponse: Content {}
extension RegisterFleetHostRequest: Content {}
extension FleetListResponse: Content {}
extension FleetHealthResponse: Content {}
extension RemoteProcessInfo: Content {}
extension RemoteProcessInfo.ProcessHighlightType: Content {}
extension MetricsSourceResponse: Content {}
extension MetricsSourceResponse.MetricsSource: Content {}
extension StartSetupRequest: Content {}
extension LifecycleRequest: Content {}
extension LifecycleRequest.LifecycleAction: Content {}
extension LifecycleResponse: Content {}
extension RemoteLogsResponse: Content {}
