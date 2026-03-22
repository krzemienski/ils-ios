import Foundation
import Fluent
import Vapor
import ILSShared

/// Evaluates incoming permission requests against configured policy rules.
///
/// Loads active policies for the request's project (plus global policies), evaluates them in
/// priority order (lower number = higher priority), and returns the action from the first
/// matching policy. Evaluation is designed to complete in under 100ms.
///
/// Matching criteria (all non-nil fields must match — AND logic):
/// - **toolName**: Case-insensitive exact match against the requesting tool's name.
/// - **pathGlob**: Glob pattern (`*`, `**`, `?`) matched against path-like fields in `toolInput`.
/// - **commandPrefix**: Prefix match against command-like fields in `toolInput`.
/// - **mcpServer**: Case-insensitive exact match against the MCP server extracted from the
///   tool name (e.g. `mcp__serverName__toolName` → `serverName`).
actor PolicyEvaluationService {

    // MARK: - Singleton

    /// Shared instance accessible throughout the backend.
    static let shared = PolicyEvaluationService()

    private static let logger = Logger(label: "ils.policy-evaluation")

    // MARK: - Evaluate

    /// Evaluate a permission request against active policies.
    ///
    /// - Parameters:
    ///   - request: The incoming permission record to evaluate.
    ///   - db: Database connection used to load policies.
    /// - Returns: A tuple containing the resolved action and the matching policy (if any).
    ///   When no policy matches, returns `(.allow, nil)` — the caller should treat a `nil`
    ///   matched policy as "no automated decision; prompt the user".
    func evaluate(
        request: PermissionRecord,
        db: Database
    ) async throws -> (PermissionPolicyAction, matchedPolicy: PermissionPolicy?) {
        let projectId = try await resolveProjectId(projectName: request.projectName, db: db)

        // Load all enabled policies sorted by priority (lowest = highest priority).
        // Filter project scope in Swift to avoid Fluent OR-null complexity.
        let allEnabled = try await PermissionPolicyModel.query(on: db)
            .filter(\.$isEnabled == true)
            .sort(\.$priority, .ascending)
            .all()

        // Restrict to global policies and (optionally) the request's project.
        let candidates = allEnabled.filter { model in
            model.projectId == nil || model.projectId == projectId
        }

        for model in candidates {
            if policyMatches(model, request: request) {
                let policy = model.toShared()
                Self.logger.info("Policy matched: '\(policy.name)' action=\(policy.action.rawValue) tool=\(request.toolName)")
                return (policy.action, matchedPolicy: policy)
            }
        }

        // No policy matched — check default-deny setting for this scope.
        let settingsQuery = PermissionPolicySettingsModel.query(on: db)
        if let projId = projectId {
            settingsQuery.filter(\.$projectId == projId)
        } else {
            settingsQuery.filter(\.$projectId == nil)
        }
        if let settings = try? await settingsQuery.first(), settings.defaultDeny {
            Self.logger.info("Default-deny triggered for unmatched request: \(request.toolName)")
            return (.deny, matchedPolicy: nil)
        }

        // Default-deny is off (or no settings row) — caller should prompt the user.
        return (.allow, matchedPolicy: nil)
    }

    // MARK: - Approval Policy Evaluation

    /// Evaluate a tool request against configured approval guardrail policies (in-memory, fast).
    ///
    /// Queries `ApprovalPolicyStore` for active policies matching the tool, path, and risk level,
    /// then returns the action from the highest-priority matching policy.
    ///
    /// Falls back to `.alwaysAsk` if no approval policy matches — the caller should prompt the user.
    ///
    /// - Parameters:
    ///   - toolName: Name of the tool requesting authorization.
    ///   - toolInput: Arbitrary tool input parameters as `AnyCodable`.
    ///   - riskLevel: Assessed risk level for the request.
    ///   - projectId: Project name/identifier for scoping, if available.
    /// - Returns: A `PolicyEvaluationResult` with the determined action, reason code, and policy ID.
    func evaluateApprovalPolicy(
        toolName: String,
        toolInput: AnyCodable,
        riskLevel: PermissionRiskLevel,
        projectId: String?
    ) async -> ILSShared.PolicyEvaluationResult {
        let policies = await ApprovalPolicyStore.shared.policiesForProject(projectId)
        let inputDict = (toolInput.value as? [String: Any]) ?? [:]

        // Evaluate policies in priority order (lowest number = highest priority).
        for policy in policies {
            guard policy.isEnabled else { continue }

            // Check if the tool matches this policy's tool rules.
            let toolMatches = matchesTool(toolName, rules: policy.toolRules)

            // Check if path globs match (if specified).
            let pathMatches = matchesPathGlobs(inputDict, globs: policy.pathPatterns ?? [])

            // Check risk level filter (if specified).
            let riskMatches = matchesRiskLevel(riskLevel, allowed: policy.confirmationRequiredRiskLevels)

            if toolMatches && pathMatches && riskMatches {
                // Determine the action from tool rules or default action.
                let action = actionForTool(toolName, rules: policy.toolRules, defaultAction: policy.defaultAction)

                // Escalate auto-approve to requireConfirmation for high/critical risk levels.
                let finalAction: PolicyAction
                if action == .autoApprove && (riskLevel == .high || riskLevel == .critical) {
                    finalAction = .requireConfirmation
                } else {
                    finalAction = action
                }

                let reasonCode = reasonCodeFor(action: finalAction)
                Self.logger.info("Approval policy matched: '\(policy.name)' action=\(finalAction.rawValue) tool=\(toolName)")

                return ILSShared.PolicyEvaluationResult(
                    action: finalAction,
                    reasonCode: reasonCode,
                    policyId: policy.id,
                    explanation: "Matched approval policy '\(policy.name)' (priority \(policy.priority))"
                )
            }
        }

        // No policy matched — default to always ask.
        Self.logger.debug("No approval policy matched for tool=\(toolName), defaulting to alwaysAsk")
        return ILSShared.PolicyEvaluationResult(
            action: .alwaysAsk,
            reasonCode: nil,
            policyId: nil,
            explanation: "No matching approval policy found. Manual approval required."
        )
    }

    // MARK: - Approval Policy Matching Helpers

    /// Check if a tool name matches any of the policy's tool rules.
    private func matchesTool(_ toolName: String, rules: [PolicyToolRule]) -> Bool {
        if rules.isEmpty { return true }
        let lower = toolName.lowercased()
        return rules.contains { (rule: PolicyToolRule) in
            rule.toolPattern == "*" || rule.toolPattern.lowercased() == lower
        }
    }

    /// Check if any path in the tool input matches the policy's path globs.
    private func matchesPathGlobs(_ inputDict: [String: Any], globs: [String]) -> Bool {
        if globs.isEmpty { return true }
        let pathKeys = ["file_path", "path", "destination", "file", "dir", "directory", "filepath"]
        let paths = pathKeys.compactMap { inputDict[$0] as? String }
        if paths.isEmpty { return true }
        return paths.contains { path in
            globs.contains { glob in globMatches(pattern: glob, string: path) }
        }
    }

    /// Check if the request's risk level matches the policy's risk level filter.
    private func matchesRiskLevel(_ riskLevel: PermissionRiskLevel, allowed: [PermissionRiskLevel]) -> Bool {
        if allowed.isEmpty { return true }
        return allowed.contains(riskLevel)
    }

    /// Get the action for a specific tool from tool rules, falling back to the default.
    private func actionForTool(_ toolName: String, rules: [PolicyToolRule], defaultAction: PolicyAction) -> PolicyAction {
        let lower = toolName.lowercased()
        if let specificRule = rules.first(where: { $0.toolPattern.lowercased() == lower }) {
            return specificRule.action
        }
        if let wildcardRule = rules.first(where: { $0.toolPattern == "*" }) {
            return wildcardRule.action
        }
        return defaultAction
    }

    /// Map a policy action to its corresponding denial reason code.
    private func reasonCodeFor(action: PolicyAction) -> DenialReasonCode? {
        switch action {
        case .autoApprove: return nil
        case .autoDeny: return .policyViolation
        case .requireConfirmation: return .highRiskBlocked
        case .alwaysAsk: return nil
        }
    }

    // MARK: - Policy Matching

    /// Determine whether a policy matches a permission request.
    ///
    /// All non-nil criteria fields must match (AND logic). Returns `true` only when
    /// every specified filter passes.
    private func policyMatches(_ policy: PermissionPolicyModel, request: PermissionRecord) -> Bool {
        // --- toolName: case-insensitive exact match ---
        if let toolName = policy.toolName {
            guard toolName.caseInsensitiveCompare(request.toolName) == .orderedSame else {
                return false
            }
        }

        // --- mcpServer: extracted from tool name pattern mcp__server__tool ---
        if let mcpServer = policy.mcpServer {
            guard let requestServer = extractMcpServer(from: request.toolName),
                  mcpServer.caseInsensitiveCompare(requestServer) == .orderedSame else {
                return false
            }
        }

        // Extract the tool input as a flat string→string dictionary for criteria checks.
        let inputDict = (request.toolInput.value as? [String: Any]) ?? [:]

        // --- pathGlob: glob-match against common path-bearing input fields ---
        if let pathGlob = policy.pathGlob {
            let pathKeys = ["file_path", "path", "destination", "file", "dir", "directory", "filepath"]
            let pathValue = pathKeys.compactMap { inputDict[$0] as? String }.first
            guard let path = pathValue, globMatches(pattern: pathGlob, string: path) else {
                return false
            }
        }

        // --- commandPrefix: prefix match against command-bearing input fields ---
        if let commandPrefix = policy.commandPrefix {
            let commandKeys = ["command", "cmd", "script", "query"]
            let commandValue = commandKeys.compactMap { inputDict[$0] as? String }.first
            guard let command = commandValue, command.hasPrefix(commandPrefix) else {
                return false
            }
        }

        return true
    }

    // MARK: - Private Helpers

    /// Look up the UUID of a project by its name.
    ///
    /// Returns `nil` when `projectName` is nil/empty or no matching project is found.
    private func resolveProjectId(projectName: String?, db: Database) async throws -> UUID? {
        guard let name = projectName, !name.isEmpty else { return nil }
        let project = try await ProjectModel.query(on: db)
            .filter(\.$name == name)
            .first()
        return project?.id
    }

    /// Extract the MCP server component from a tool name formatted as `mcp__serverName__toolName`.
    ///
    /// Returns `nil` if the tool name does not follow the MCP naming convention.
    private func extractMcpServer(from toolName: String) -> String? {
        let parts = toolName.components(separatedBy: "__")
        guard parts.count >= 3, parts[0].caseInsensitiveCompare("mcp") == .orderedSame else {
            return nil
        }
        return parts[1]
    }

    /// Test whether a glob pattern matches a string.
    ///
    /// Supported wildcards:
    /// - `**` — matches any sequence of characters including path separators.
    /// - `*`  — matches any sequence of characters except `/`.
    /// - `?`  — matches a single character except `/`.
    ///
    /// Matching is case-insensitive.
    private func globMatches(pattern: String, string: String) -> Bool {
        var regexString = "^"
        var index = pattern.startIndex

        while index < pattern.endIndex {
            let ch = pattern[index]
            switch ch {
            case "*":
                let nextIndex = pattern.index(after: index)
                if nextIndex < pattern.endIndex && pattern[nextIndex] == "*" {
                    // "**" — match anything including "/"
                    regexString += ".*"
                    index = pattern.index(after: nextIndex)
                    // Absorb an optional trailing separator so "src/**" matches "src/foo/bar"
                    if index < pattern.endIndex && pattern[index] == "/" {
                        regexString += "(?:/?$|.*/)"
                        index = pattern.index(after: index)
                    }
                } else {
                    // "*" — match anything except "/"
                    regexString += "[^/]*"
                    index = nextIndex
                }
            case "?":
                regexString += "[^/]"
                index = pattern.index(after: index)
            case "^", "$", "+", "{", "}", "[", "]", "|", "(", ")", ".", "\\":
                regexString += "\\\(ch)"
                index = pattern.index(after: index)
            default:
                regexString += String(ch)
                index = pattern.index(after: index)
            }
        }

        regexString += "$"

        guard let regex = try? NSRegularExpression(pattern: regexString, options: .caseInsensitive) else {
            return false
        }
        let nsRange = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [], range: nsRange) != nil
    }
}
