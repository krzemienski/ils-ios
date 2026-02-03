import Vapor
import ILSShared

struct ConfigController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let config = routes.grouped("config")

        config.get(use: get)
        config.put(use: update)
        config.delete(use: delete)
        config.post("validate", use: validate)
    }

    /// GET /config - Get configuration for a scope
    @Sendable
    func get(req: Request) async throws -> APIResponse<ConfigInfo> {
        let scope = req.query[String.self, at: "scope"] ?? "user"

        let config = try fileSystem.readConfig(scope: scope)

        return APIResponse(
            success: true,
            data: config
        )
    }

    /// PUT /config - Update configuration
    @Sendable
    func update(req: Request) async throws -> APIResponse<ConfigInfo> {
        let input = try req.content.decode(UpdateConfigRequest.self)

        let config = try fileSystem.writeConfig(scope: input.scope, content: input.content)

        return APIResponse(
            success: true,
            data: config
        )
    }

    /// DELETE /config - Reset configuration to defaults
    @Sendable
    func delete(req: Request) async throws -> APIResponse<ConfigInfo> {
        let scope = req.query[String.self, at: "scope"] ?? "user"

        let config = try fileSystem.deleteConfig(scope: scope)

        return APIResponse(
            success: true,
            data: config
        )
    }

    /// POST /config/validate - Validate configuration
    @Sendable
    func validate(req: Request) async throws -> APIResponse<ConfigValidationResult> {
        let input = try req.content.decode(ValidateConfigRequest.self)

        var errors: [String] = []

        // Validate model name if present
        if let model = input.content.model {
            let validModels = ["sonnet", "opus", "haiku", "claude-sonnet-4-5", "claude-opus-4-5", "claude-3-5-sonnet", "claude-3-5-haiku"]
            if !validModels.contains(model) && !model.hasPrefix("claude-") {
                errors.append("Invalid model name: \(model)")
            }
        }

        // Validate permissions
        if let permissions = input.content.permissions {
            if let allow = permissions.allow {
                for tool in allow {
                    if tool.isEmpty {
                        errors.append("permissions.allow contains empty string")
                    }
                }
            }
            if let deny = permissions.deny {
                for tool in deny {
                    if tool.isEmpty {
                        errors.append("permissions.deny contains empty string")
                    }
                }
            }
            if let defaultMode = permissions.defaultMode {
                let validModes = ["ask", "allow", "deny"]
                if !validModes.contains(defaultMode) {
                    errors.append("Invalid permissions.defaultMode: \(defaultMode). Must be one of: \(validModes.joined(separator: ", "))")
                }
            }
        }

        // Validate environment variables
        if let env = input.content.env {
            for (key, value) in env {
                if key.isEmpty {
                    errors.append("env contains empty key")
                }
                if value.isEmpty {
                    errors.append("env.\(key) contains empty value")
                }
            }
        }

        // Validate hooks
        if let hooks = input.content.hooks {
            validateHookGroups(hooks.sessionStart, hookType: "SessionStart", errors: &errors)
            validateHookGroups(hooks.subagentStart, hookType: "SubagentStart", errors: &errors)
            validateHookGroups(hooks.userPromptSubmit, hookType: "UserPromptSubmit", errors: &errors)
            validateHookGroups(hooks.preToolUse, hookType: "PreToolUse", errors: &errors)
            validateHookGroups(hooks.postToolUse, hookType: "PostToolUse", errors: &errors)
        }

        // Validate enabled plugins
        if let enabledPlugins = input.content.enabledPlugins {
            for (pluginName, _) in enabledPlugins {
                if pluginName.isEmpty {
                    errors.append("enabledPlugins contains empty plugin name")
                }
            }
        }

        // Validate extra known marketplaces
        if let marketplaces = input.content.extraKnownMarketplaces {
            for (name, url) in marketplaces {
                if name.isEmpty {
                    errors.append("extraKnownMarketplaces contains empty marketplace name")
                }
                if url.isEmpty {
                    errors.append("extraKnownMarketplaces.\(name) contains empty URL")
                } else if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                    errors.append("extraKnownMarketplaces.\(name) must be a valid HTTP(S) URL")
                }
            }
        }

        // Validate status line
        if let statusLine = input.content.statusLine {
            if let type = statusLine.type {
                let validTypes = ["command", "git", "path", "none"]
                if !validTypes.contains(type) {
                    errors.append("Invalid statusLine.type: \(type). Must be one of: \(validTypes.joined(separator: ", "))")
                }
            }
            if let command = statusLine.command {
                if command.isEmpty {
                    errors.append("statusLine.command cannot be empty")
                }
            }
        }

        // Validate auto updates channel
        if let channel = input.content.autoUpdatesChannel {
            let validChannels = ["stable", "beta", "dev", "none"]
            if !validChannels.contains(channel) {
                errors.append("Invalid autoUpdatesChannel: \(channel). Must be one of: \(validChannels.joined(separator: ", "))")
            }
        }

        // Validate theme
        if let theme = input.content.theme {
            if let colorScheme = theme.colorScheme {
                let validSchemes = ["light", "dark", "system"]
                if !validSchemes.contains(colorScheme) {
                    errors.append("Invalid theme.colorScheme: \(colorScheme). Must be one of: \(validSchemes.joined(separator: ", "))")
                }
            }
            if let accentColor = theme.accentColor {
                if accentColor.isEmpty {
                    errors.append("theme.accentColor cannot be empty")
                } else if !accentColor.hasPrefix("#") && !isNamedColor(accentColor) {
                    errors.append("Invalid theme.accentColor: \(accentColor). Must be a hex color (#RRGGBB) or named color")
                }
            }
        }

        return APIResponse(
            success: true,
            data: ConfigValidationResult(isValid: errors.isEmpty, errors: errors)
        )
    }

    /// Helper to validate hook groups
    private func validateHookGroups(_ groups: [HookGroup]?, hookType: String, errors: inout [String]) {
        guard let groups = groups else { return }

        for (index, group) in groups.enumerated() {
            if let hooks = group.hooks {
                for (hookIndex, hook) in hooks.enumerated() {
                    if let type = hook.type {
                        let validTypes = ["shell", "http", "webhook"]
                        if !validTypes.contains(type) {
                            errors.append("Invalid hooks.\(hookType)[\(index)].hooks[\(hookIndex)].type: \(type). Must be one of: \(validTypes.joined(separator: ", "))")
                        }
                    }
                    if let command = hook.command {
                        if command.isEmpty {
                            errors.append("hooks.\(hookType)[\(index)].hooks[\(hookIndex)].command cannot be empty")
                        }
                    }
                }
            }
        }
    }

    /// Helper to check if a string is a named color
    private func isNamedColor(_ color: String) -> Bool {
        let namedColors = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "gray", "black", "white", "cyan", "magenta", "brown", "teal", "indigo"]
        return namedColors.contains(color.lowercased())
    }
}
