import Vapor
import ILSShared

struct ConfigController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let config = routes.grouped("config")

        config.get(use: get)
        config.get("effective", use: effective)
        config.put(use: update)
        config.post("validate", use: validate)
        config.post("validate-api-key", use: validateAPIKey)
    }

    /// GET /config/effective - Get merged effective configuration with scope annotations
    @Sendable
    func effective(req: Request) async throws -> APIResponse<EffectiveConfig> {
        let effectiveConfig = fileSystem.readEffectiveConfig()
        return APIResponse(success: true, data: effectiveConfig)
    }

    /// GET /config - Get configuration for a scope
    @Sendable
    func get(req: Request) async throws -> APIResponse<ConfigInfo> {
        let scopeString = req.query[String.self, at: "scope"] ?? "user"
        guard let scope = ConfigScope(rawValue: scopeString) else {
            throw Abort(.badRequest, reason: "Invalid scope '\(scopeString)'. Must be one of: user, project, local")
        }

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

        // Scope is already type-safe via ConfigScope enum in UpdateConfigRequest
        let config = try fileSystem.writeConfig(scope: input.scope, content: input.content)

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

        // Validate model name if present.
        // Accepts short aliases (sonnet, opus, haiku) and full versioned model IDs.
        // Any string beginning with "claude-" is accepted to accommodate future model releases.
        if let model = input.content.model {
            let validShortAliases = [
                "sonnet", "opus", "haiku",
                // claude-3 family
                "claude-3-5-sonnet", "claude-3-5-haiku", "claude-3-opus", "claude-3-sonnet", "claude-3-haiku",
                // claude-4 family (as of 2026-02)
                "claude-sonnet-4-5", "claude-opus-4-5",
                "claude-sonnet-4-6", "claude-opus-4-6",
                "claude-haiku-4-5"
            ]
            if !validShortAliases.contains(model) && !model.hasPrefix("claude-") {
                errors.append("Invalid model name: \(model). Use a short alias (sonnet, opus, haiku) or a full claude- prefixed model ID.")
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

    /// POST /config/validate-api-key - Validate an Anthropic API key
    @Sendable
    func validateAPIKey(req: Request) async throws -> APIResponse<APIKeyValidationResult> {
        let input = try req.content.decode(ValidateAPIKeyRequest.self)

        let url = URI(string: "https://api.anthropic.com/v1/models")
        let response = try await req.client.get(url) { clientReq in
            clientReq.headers.add(name: "x-api-key", value: input.apiKey)
            clientReq.headers.add(name: "anthropic-version", value: "2023-06-01")
        }

        let isValid = response.status == .ok
        var errorMessage: String? = nil

        if !isValid {
            if response.status == .unauthorized || response.status == .forbidden {
                errorMessage = "Invalid API key"
            } else {
                errorMessage = "Unexpected response from Anthropic API: \(response.status.code)"
            }
        }

        return APIResponse(
            success: true,
            data: APIKeyValidationResult(isValid: isValid, error: errorMessage)
        )
    }

}

// MARK: - Request/Response Types

struct ValidateAPIKeyRequest: Content {
    let apiKey: String
}

struct APIKeyValidationResult: Content {
    let isValid: Bool
    let error: String?
}

