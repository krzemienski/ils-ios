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

// MARK: - Request Types
extension CreateProjectRequest: Content {}
extension UpdateProjectRequest: Content {}
extension CreateCheckpointRequest: Content {}
extension BulkExportRequest: Content {}
extension ImportSessionRequest: Content {}
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
extension UpdateConfigRequest: Content {}
extension ValidateConfigRequest: Content {}
extension CreateCustomThemeRequest: Content {}
extension UpdateCustomThemeRequest: Content {}
extension CreateTemplateRequest: Content {}
extension UpdateTemplateRequest: Content {}
extension BulkDeleteTemplatesRequest: Content {}

// MARK: - Paginated Response
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

// MARK: - Response Types
extension RenameSessionRequest: Content {}
extension BulkDeleteSessionsRequest: Content {}
extension BulkDeleteProjectsRequest: Content {}
extension MessageSearchResult: Content {}
extension SessionComparisonResult: Content {}
extension SessionWithMessages: Content {}
extension RecentlyComparedPair: Content {}
extension ChatExport: Content {}
extension ChatExportSession: Content {}
extension ChatExportMessage: Content {}
extension ConfigValidationResult: Content {}
extension StatsResponse: Content {}
extension CountStat: Content {}
extension SessionStat: Content {}
extension MCPStat: Content {}
extension PluginStat: Content {}
extension HealthSummary: Content {}
extension SessionHealthScore: Content {}
extension HealthScoreFactor: Content {}
extension HealthScoreLevel: Content {}
extension ProjectHealthSummary: Content {}
extension ProjectHealthSummary.HealthScoreTrendPoint: Content {}
extension DeletedResponse: Content {}
extension DataErasureResponse: Content {}
extension IntegrityCheckResult: Content {}
extension AcknowledgedResponse: Content {}
extension CancelledResponse: Content {}
extension EnabledResponse: Content {}
extension ProjectGroupInfo: Content {}
extension ServerStatus: Content {}
extension Marketplace: Content {}
extension GitHubSearchResult: Content {}
extension GitHubRepoPreview: Content {}
extension GitHubFileEntry: Content {}

// MARK: - Model Types
extension SessionTemplate: Content {}
extension Project: Content {}
extension ChatSession: Content {}
extension SessionCheckpoint: Content {}
extension Message: Content {}
extension MessageRole: Content {}
extension ExternalSession: Content {}
extension Skill: Content {}
extension Plugin: Content {}
extension PluginMarketplace: Content {}
extension PluginInfo: Content {}
extension PluginUpdateInfo: Content {}
extension MCPServer: Content {}
extension MCPHealthResponse: Content {}
extension MCPLogEntry: Content {}
extension MCPLogsResponse: Content {}
extension MCPRestartResponse: Content {}
extension MCPMarketplaceEntry: Content {}
extension MCPEnvVarSpec: Content {}
extension MCPValidationResult: Content {}
extension MCPPreset: Content {}
extension MCPPresetCategory: Content {}
extension MCPPresetListResponse: Content {}
extension ClaudeConfig: Content {}
extension PermissionsConfig: Content {}
extension HooksConfig: Content {}
extension HookDefinition: Content {}
extension ConfigInfo: Content {}
extension ConfigProfiles: Content {}
extension ConfigOverride: Content {}
extension EffectiveConfig: Content {}
extension CustomTheme: Content {}
extension HostProfile: Content {}
extension HostProfile.HealthStatus: Content {}
extension HostProfileListResponse: Content {}
extension HostProfileHealthResponse: Content {}
extension RegisterHostProfileRequest: Content {}
extension ColorTokens: Content {}
extension TypographyTokens: Content {}
extension SpacingTokens: Content {}
extension CornerRadiusTokens: Content {}
extension ShadowTokens: Content {}

// MARK: - Fork Tree Types
extension SessionForkNode: Content {}
extension SessionForkTreeResponse: Content {}

// MARK: - Suggestion Types
extension SessionSuggestion: Content {}
extension SkillSuggestion: Content {}
extension AbandonedSessionSuggestion: Content {}
extension ContinuationSummary: Content {}
extension SuggestionFeedbackRequest: Content {}

// MARK: - Model Routing & Stats Types
extension ModelRoutingRequest: Content {}
extension ModelRoutingResponse: Content {}
extension ModelUsageStat: Content {}
extension AnalyticsModelUsageStat: Content {}
extension ModelStatsResponse: Content {}
extension UpdateSessionModelRequest: Content {}

// MARK: - Activity Feed Types
extension ActivityEvent: Content {}
extension ActivityEventType: Content {}
extension ActivityEventSeverity: Content {}
extension ActivityFeedFilter: Content {}
extension ActivityFeedResponse: Content {}

// MARK: - Recording Types
extension SessionRecording: Content {}
extension RecordingEvent: Content {}
extension RecordingStatus: Content {}
extension RecordingEventType: Content {}
extension PlaybackSpeed: Content {}
extension RecordingListResponse: Content {}
extension RecordingEventsResponse: Content {}
extension StartRecordingRequest: Content {}
extension StopRecordingRequest: Content {}
extension ExportRecordingRequest: Content {}
extension ExportRecordingResponse: Content {}

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

// MARK: - Checkpoint Types
extension Checkpoint: Content {}
extension CreateCheckpointRequest: Content {}
extension RestoreCheckpointResponse: Content {}

// MARK: - Analytics DTOs
extension ActivityDataPoint: Content {}
extension ActivityTimelineResponse: Content {}
extension SessionMetricsResponse: Content {}
extension SkillUsageStat: Content {}
extension SkillAnalyticsResponse: Content {}
extension AnalyticsSummary: Content {}
extension AnalyticsExportData: Content {}

// MARK: - Search History Types
extension SearchHistoryEntry: Content {}
extension MessageSearchFilters: Content {}
