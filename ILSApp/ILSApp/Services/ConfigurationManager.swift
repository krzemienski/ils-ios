import SwiftUI
import ILSShared

/// Manages Claude Code configuration lifecycle: loading, validating, and saving
@MainActor
class ConfigurationManager: ObservableObject {
    @Published var currentScope: String = "user"
    @Published var rawJSON: String = ""
    @Published var validationStatus: ValidationStatus = .unknown
    @Published var hasUnsavedChanges: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var originalJSON: String = ""
    private let apiClient: APIClient

    enum ValidationStatus: String {
        case valid = "Valid JSON"
        case invalid = "Invalid JSON"
        case unknown = "Not validated"
        case validating = "Validating..."
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Load config for a given scope
    func loadConfig(scope: String) async {
        currentScope = scope
        isLoading = true
        error = nil
        do {
            let response: APIResponse<ConfigInfo> = try await apiClient.get("/config?scope=\(scope)")
            if let configInfo = response.data {
                // Convert ClaudeConfig to pretty-printed JSON
                if let jsonData = try? JSONEncoder().encode(configInfo.content),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    // Pretty print the JSON
                    if let prettyData = try? JSONSerialization.jsonObject(with: jsonData),
                       let prettyJsonData = try? JSONSerialization.data(withJSONObject: prettyData, options: [.prettyPrinted, .sortedKeys]),
                       let prettyString = String(data: prettyJsonData, encoding: .utf8) {
                        rawJSON = prettyString
                        originalJSON = prettyString
                    } else {
                        rawJSON = jsonString
                        originalJSON = jsonString
                    }
                    hasUnsavedChanges = false
                    validationStatus = configInfo.isValid ? .valid : .invalid
                } else {
                    throw NSError(domain: "ConfigurationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize config"])
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Validate JSON content
    func validateJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else {
            validationStatus = .invalid
            return
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            // Try to decode as ClaudeConfig to ensure structure is valid
            _ = try JSONDecoder().decode(ClaudeConfig.self, from: data)
            validationStatus = .valid
        } catch {
            validationStatus = .invalid
        }
    }

    /// Save changes to backend
    func saveChanges() async {
        isLoading = true
        error = nil
        do {
            // Parse the raw JSON into ClaudeConfig
            guard let data = rawJSON.data(using: .utf8) else {
                throw NSError(domain: "ConfigurationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
            }

            let claudeConfig = try JSONDecoder().decode(ClaudeConfig.self, from: data)

            // Send to backend
            let body = UpdateConfigRequest(scope: currentScope, content: claudeConfig)
            let _: APIResponse<ConfigInfo> = try await apiClient.put("/config", body: body)

            originalJSON = rawJSON
            hasUnsavedChanges = false
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Update the raw JSON when user edits text
    func updateRawJSON(_ newValue: String) {
        rawJSON = newValue
        hasUnsavedChanges = newValue != originalJSON
        validateJSON(newValue)
    }

    /// Update a quick setting by modifying the raw JSON
    func updateQuickSetting(key: String, value: Any) {
        guard let data = rawJSON.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        dict[key] = value
        if let newData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let newString = String(data: newData, encoding: .utf8) {
            rawJSON = newString
            hasUnsavedChanges = newString != originalJSON
            validationStatus = .valid
        }
    }
}
