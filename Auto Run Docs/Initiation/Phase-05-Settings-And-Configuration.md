# Phase 05: Settings and Configuration Management

This phase completes the app's configuration capabilities—reading and writing Claude Code settings, managing API keys, and customizing behavior. Users should be able to view their current config and make safe modifications through the iOS interface.

## Tasks

- [x] Complete ConfigController backend implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ConfigController.swift`
  - Implement `getConfig()` to read ~/.claude/config.json
  - Implement `updateConfig()` to safely write config changes
  - Validate config structure before writing (prevent corruption)
  - Handle missing config file by returning sensible defaults
  - Support reading/writing specific config keys via path parameter

  **Completed:** ConfigController already fully implemented with:
  - `GET /config?scope=user|project|local` - reads config from appropriate path
  - `PUT /config` - writes config with scope and content validation
  - `POST /config/validate` - validates model names and permissions structure
  - FileSystemService handles missing files by returning empty ClaudeConfig defaults
  - Supports user/project/local scopes via query parameter

- [ ] Add config DTOs to ILSShared:
  - Review `/Users/nick/Desktop/ils-ios/Sources/ILSShared/Models/ClaudeConfig.swift`
  - Ensure ClaudeConfig model covers: apiKey, defaultModel, permissions, theme
  - Add ConfigUpdateRequest DTO for partial updates
  - Ensure all fields are optional for partial update support

- [ ] Update iOS SettingsView for config display:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/SettingsView.swift`
  - Fetch current config from backend on view appear
  - Display config sections: General, Permissions, Advanced
  - Show current values with appropriate UI controls (toggles, pickers, text fields)
  - Add section for backend connection settings (host, port)

- [ ] Implement config editing in SettingsView:
  - Allow editing safe config values (theme, default model)
  - Show confirmation before saving changes
  - Send update request to backend
  - Refresh display after successful save
  - Show error alert if save fails with reason

- [ ] Add API key management (view-only for security):
  - Display masked API key (show last 4 characters only)
  - Show "API Key Configured" or "No API Key" status
  - Do NOT allow editing API key through iOS app (security)
  - Link to instructions for setting API key via terminal

- [ ] Implement server connection configuration:
  - Allow changing backend host/port in iOS app settings
  - Store connection settings in UserDefaults
  - Update APIClient baseURL when settings change
  - Test connection button to verify backend reachability
  - Show connection status indicator in settings

- [ ] Test settings flow end-to-end:
  - Start backend server
  - Run iOS app and navigate to Settings
  - Verify current config displays correctly
  - Change a setting (e.g., theme preference)
  - Verify change persists after app restart
  - Verify change reflected in ~/.claude/config.json
