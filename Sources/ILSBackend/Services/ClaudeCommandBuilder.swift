// Sources/ILSBackend/Services/ClaudeCommandBuilder.swift

import Foundation
import ILSShared
import Logging

/// Builds CLI commands and SDK configuration for Claude subprocess execution.
///
/// Extracted from `ClaudeExecutorService` to separate command-construction concerns
/// from process-lifecycle management. All methods are static; the enum has no cases.
enum ClaudeCommandBuilder {

    private static let logger = Logger(label: "ils.claude-command-builder")

    // MARK: - Codable Payloads

    /// Codable struct for Agent SDK wrapper configuration.
    struct SDKConfig: Codable {
        let prompt: String
        let options: SDKOptions
    }

    /// Codable struct for SDK execution options passed to sdk-wrapper.mjs.
    /// All fields are optional; nil values are omitted from JSON output.
    struct SDKOptions: Codable {
        var model: String?
        var maxTurns: Int?
        var allowedTools: [String]?
        var disallowedTools: [String]?
        var permissionMode: String?
        var systemPrompt: String?
        var appendSystemPrompt: String?
        var resume: String?
        var continueConversation: Bool?
        var forkSession: Bool?
        var sessionId: String?
        var cwd: String?
        var includePartialMessages: Bool?

        init(
            model: String? = nil,
            maxTurns: Int? = nil,
            allowedTools: [String]? = nil,
            disallowedTools: [String]? = nil,
            permissionMode: String? = nil,
            systemPrompt: String? = nil,
            appendSystemPrompt: String? = nil,
            resume: String? = nil,
            continueConversation: Bool? = nil,
            forkSession: Bool? = nil,
            sessionId: String? = nil,
            cwd: String? = nil,
            includePartialMessages: Bool? = nil
        ) {
            self.model = model
            self.maxTurns = maxTurns
            self.allowedTools = allowedTools
            self.disallowedTools = disallowedTools
            self.permissionMode = permissionMode
            self.systemPrompt = systemPrompt
            self.appendSystemPrompt = appendSystemPrompt
            self.resume = resume
            self.continueConversation = continueConversation
            self.forkSession = forkSession
            self.sessionId = sessionId
            self.cwd = cwd
            self.includePartialMessages = includePartialMessages
        }
    }

    // MARK: - SDK Config Building

    /// Build a JSON configuration object for the Agent SDK wrapper.
    ///
    /// The config includes the prompt and all options in a format that
    /// `sdk-wrapper.mjs` maps to the Agent SDK's `query()` function.
    ///
    /// - Parameters:
    ///   - prompt: User prompt text
    ///   - options: Execution options to encode
    ///   - workingDirectory: Optional working directory for project context
    /// - Returns: JSON string for passing as a CLI argument to sdk-wrapper.mjs
    static func buildSDKConfig(
        prompt: String,
        options: ExecutionOptions,
        workingDirectory: String?
    ) -> String {
        let sdkOptions = SDKOptions(
            model: options.model,
            maxTurns: options.maxTurns,
            allowedTools: options.allowedTools,
            disallowedTools: options.disallowedTools,
            permissionMode: options.permissionMode?.rawValue,
            systemPrompt: (options.systemPrompt?.isEmpty == false) ? options.systemPrompt : nil,
            appendSystemPrompt: (options.appendSystemPrompt?.isEmpty == false) ? options.appendSystemPrompt : nil,
            resume: options.resume,
            continueConversation: options.continueConversation == true ? true : nil,
            forkSession: options.forkSession == true ? true : nil,
            sessionId: options.sessionId,
            cwd: workingDirectory,
            includePartialMessages: options.includePartialMessages == true ? true : nil
        )

        let config = SDKConfig(prompt: prompt, options: sdkOptions)

        do {
            let jsonData = try JSONEncoder().encode(config)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode SDK config: \(error)")
            // Fallback: encode just the prompt safely
            let fallback = SDKConfig(prompt: String(prompt.prefix(100)), options: SDKOptions())
            if let safeData = try? JSONEncoder().encode(fallback),
               let safeString = String(data: safeData, encoding: .utf8) {
                return safeString
            }
            return "{}"
        }
    }

    // MARK: - CLI Command Building

    /// Build the full Claude CLI command string from execution options.
    ///
    /// Constructs a command like: `claude -p --verbose --output-format stream-json [options]`
    ///
    /// - Parameter options: Execution options to convert to CLI arguments
    /// - Returns: Shell command string (prompt sent via stdin separately)
    static func buildCommand(options: ExecutionOptions) -> String {
        var args: [String] = ["claude", "-p", "--verbose"]

        // Output format: always stream-json for structured streaming
        args.append("--output-format")
        args.append("stream-json")

        // Always include partial messages for character-by-character streaming
        args.append("--include-partial-messages")

        // Max turns
        if let maxTurns = options.maxTurns {
            args.append("--max-turns")
            args.append("\(maxTurns)")
        } else {
            args.append("--max-turns")
            args.append("1")
        }

        // Model
        if let model = options.model {
            args.append("--model")
            args.append(model)
        }

        // Fallback model
        if let fallbackModel = options.fallbackModel {
            args.append("--fallback-model")
            args.append(fallbackModel)
        }

        // Setting sources: skip user settings for backend (faster startup)
        args.append("--setting-sources")
        args.append("project,local")

        // Permission mode: use specified mode or default to CLI's default (interactive permissions)
        if let mode = options.permissionMode {
            switch mode {
            case .bypassPermissions:
                args.append("--dangerously-skip-permissions")
            default:
                args.append("--permission-mode")
                args.append(mode.rawValue)
            }
        } else {
            args.append("--permission-mode")
            args.append(PermissionMode.default.rawValue)
        }

        // Resume existing session
        if let resume = options.resume {
            args.append("--resume")
            args.append(resume)
        }

        // Continue conversation (resume most recent)
        if options.continueConversation == true {
            args.append("--continue")
        }

        // Fork session
        if options.forkSession == true {
            args.append("--fork-session")
        }

        // Session ID (specific UUID)
        if let sessionId = options.sessionId {
            args.append("--session-id")
            args.append(sessionId)
        }

        // System prompt
        if let systemPrompt = options.systemPrompt, !systemPrompt.isEmpty {
            args.append("--system-prompt")
            args.append(shellEscape(systemPrompt))
        }

        // Append system prompt
        if let appendSystemPrompt = options.appendSystemPrompt, !appendSystemPrompt.isEmpty {
            args.append("--append-system-prompt")
            args.append(shellEscape(appendSystemPrompt))
        }

        // Max budget
        if let maxBudget = options.maxBudgetUSD {
            args.append("--max-budget-usd")
            args.append(String(format: "%.2f", maxBudget))
        }

        // Include partial messages (character-by-character streaming)
        if options.includePartialMessages == true {
            args.append("--include-partial-messages")
        }

        // No session persistence
        if options.noSessionPersistence == true {
            args.append("--no-session-persistence")
        }

        // Additional directories
        if let addDirs = options.addDirs, !addDirs.isEmpty {
            for dir in addDirs {
                args.append("--add-dir")
                args.append(dir)
            }
        }

        // Allowed tools
        if let allowedTools = options.allowedTools, !allowedTools.isEmpty {
            args.append("--allowedTools")
            args.append("\"\(allowedTools.joined(separator: ","))\"")
        }

        // Disallowed tools
        if let disallowedTools = options.disallowedTools, !disallowedTools.isEmpty {
            args.append("--disallowedTools")
            args.append("\"\(disallowedTools.joined(separator: ","))\"")
        }

        // Tools (built-in tool list)
        if let tools = options.tools, !tools.isEmpty {
            args.append("--tools")
            args.append("\"\(tools.joined(separator: ","))\"")
        }

        // JSON schema for structured output
        if let jsonSchema = options.jsonSchema, !jsonSchema.isEmpty {
            args.append("--json-schema")
            args.append(shellEscape(jsonSchema))
        }

        // MCP config file
        if let mcpConfig = options.mcpConfig, !mcpConfig.isEmpty {
            args.append("--mcp-config")
            args.append(mcpConfig)
        }

        // Custom agents JSON
        if let customAgents = options.customAgents, !customAgents.isEmpty {
            args.append("--agents")
            args.append(shellEscape(customAgents))
        }

        // Input format
        if let inputFormat = options.inputFormat, !inputFormat.isEmpty {
            args.append("--input-format")
            args.append(inputFormat)
        }

        // Agent mode
        if let agent = options.agent, !agent.isEmpty {
            args.append("--agent")
            args.append(agent)
        }

        // Beta flags
        if let betas = options.betas, !betas.isEmpty {
            args.append("--betas")
            args.append(betas.joined(separator: ","))
        }

        // Debug mode
        if options.debug == true {
            args.append("--debug")
        }

        // Debug file
        if let debugFile = options.debugFile, !debugFile.isEmpty {
            args.append("--debug-file")
            args.append(debugFile)
        }

        // Disable slash commands
        if options.disableSlashCommands == true {
            args.append("--disable-slash-commands")
        }

        // System prompt file
        if let systemPromptFile = options.systemPromptFile, !systemPromptFile.isEmpty {
            args.append("--system-prompt-file")
            args.append(systemPromptFile)
        }

        // Append system prompt file
        if let appendSystemPromptFile = options.appendSystemPromptFile, !appendSystemPromptFile.isEmpty {
            args.append("--append-system-prompt-file")
            args.append(appendSystemPromptFile)
        }

        // Plugin directory
        if let pluginDir = options.pluginDir, !pluginDir.isEmpty {
            args.append("--plugin-dir")
            args.append(pluginDir)
        }

        // Strict MCP config
        if options.strictMcpConfig == true {
            args.append("--strict-mcp-config")
        }

        // Custom settings path
        if let settingsPath = options.settingsPath, !settingsPath.isEmpty {
            args.append("--settings")
            args.append(settingsPath)
        }

        return args.joined(separator: " ")
    }

    // MARK: - Shell Escaping

    /// Shell-escape a string by wrapping in single quotes and escaping internal quotes.
    /// - Parameter value: String to escape
    /// - Returns: Shell-safe quoted string
    static func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
