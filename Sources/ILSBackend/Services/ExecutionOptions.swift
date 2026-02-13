import Foundation
import ILSShared

/// Options for Claude CLI execution, mirroring ChatOptions from ILSShared.
///
/// Supports all Claude CLI flags including session management, model selection,
/// permissions, tool control, and output formatting.
struct ExecutionOptions {
    var sessionId: String?
    var model: String?
    var permissionMode: ILSShared.PermissionMode?
    var maxTurns: Int?
    var maxBudgetUSD: Double?
    var allowedTools: [String]?
    var disallowedTools: [String]?
    var resume: String?
    var forkSession: Bool?

    // Claude Code CLI parity fields
    var systemPrompt: String?
    var appendSystemPrompt: String?
    var addDirs: [String]?
    var continueConversation: Bool?
    var includePartialMessages: Bool?
    var fallbackModel: String?
    var jsonSchema: String?
    var mcpConfig: String?
    var customAgents: String?
    var tools: [String]?
    var noSessionPersistence: Bool?
    var inputFormat: String?
    var agent: String?
    var betas: [String]?
    var debug: Bool?
    var debugFile: String?
    var disableSlashCommands: Bool?
    var systemPromptFile: String?
    var appendSystemPromptFile: String?
    var pluginDir: String?
    var strictMcpConfig: Bool?
    var settingsPath: String?

    init(from chatOptions: ChatOptions? = nil) {
        // Only copy properties that exist on the shared ChatOptions DTO.
        // Remaining ExecutionOptions fields (CLI-only flags) default to nil.
        self.model = chatOptions?.model
        self.permissionMode = chatOptions?.permissionMode
        self.maxTurns = chatOptions?.maxTurns
        self.maxBudgetUSD = chatOptions?.maxBudgetUSD
        self.allowedTools = chatOptions?.allowedTools
        self.disallowedTools = chatOptions?.disallowedTools
        self.resume = chatOptions?.resume
        self.forkSession = chatOptions?.forkSession
        self.systemPrompt = chatOptions?.systemPrompt
        self.appendSystemPrompt = chatOptions?.appendSystemPrompt
        self.addDirs = chatOptions?.addDirs
        self.continueConversation = chatOptions?.continueConversation
        self.includePartialMessages = chatOptions?.includePartialMessages
        self.noSessionPersistence = chatOptions?.noSessionPersistence
        self.inputFormat = chatOptions?.inputFormat
        self.agent = chatOptions?.agent
        self.betas = chatOptions?.betas
        self.debug = chatOptions?.debug
    }
}
