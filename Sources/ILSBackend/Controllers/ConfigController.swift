import Vapor
import ILSShared

struct ConfigController: RouteCollection {
    let configService = ClaudeConfigService()

    func boot(routes: RoutesBuilder) throws {
        let config = routes.grouped("config")

        config.get(use: get)
        config.put(use: update)
        config.post("validate", use: validate)
    }

    /// GET /config - Get configuration for a scope
    @Sendable
    func get(req: Request) async throws -> APIResponse<ConfigInfo> {
        let scope = req.query[String.self, at: "scope"] ?? "user"

        let config = try configService.readConfig(scope: scope)

        return APIResponse(
            success: true,
            data: config
        )
    }

    /// PUT /config - Update configuration
    @Sendable
    func update(req: Request) async throws -> APIResponse<ConfigInfo> {
        let input = try req.content.decode(UpdateConfigRequest.self)

        let config = try configService.writeConfig(scope: input.scope, content: input.content)

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
        }

        return APIResponse(
            success: true,
            data: ConfigValidationResult(isValid: errors.isEmpty, errors: errors)
        )
    }
}
