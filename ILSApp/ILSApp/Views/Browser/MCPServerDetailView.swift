import SwiftUI
import ILSShared

// MARK: - MCP Server Detail View (extracted from MCPServerListView.swift, migrated to theme)

/// Detail view for a single MCP (Model Context Protocol) server configuration.
///
/// Displays the server's command, arguments, environment variables, connection status,
/// and configuration scope. Sensitive environment variable values (API keys, tokens,
/// secrets) are automatically detected and masked, with a timed reveal toggle so users
/// can inspect them without leaving credentials permanently visible.
///
/// ## Topics
/// ### State
/// - ``server`` - The MCP server whose details are being displayed
/// - ``showCopiedToast`` - Whether the "Copied to clipboard" toast is visible
/// - ``revealedKeys`` - Set of environment variable keys currently shown unmasked
/// - ``autoHideTasks`` - Background tasks that auto-hide revealed sensitive values
///
/// ### View Sections
/// - Command — executable path and argument list
/// - Environment Variables — masked/revealed key-value pairs with sensitivity detection
/// - Configuration — scope, connection status indicator, and optional config path
/// - Full Command — complete shell-ready command string with copy toolbar button
struct MCPServerDetailView: View {
    /// The MCP server whose configuration and status this view presents.
    let server: MCPServer
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether the "Copied to clipboard" confirmation toast is currently visible.
    @State private var showCopiedToast = false
    /// Set of environment variable keys whose values are currently revealed in plain text.
    @State private var revealedKeys: Set<String> = []
    /// Auto-hide tasks keyed by environment variable name; each cancels after 5 seconds to re-mask the value.
    @State private var autoHideTasks: [String: Task<Void, Never>] = [:]

    /// Patterns that indicate a value is sensitive and should be masked.
    private static let sensitivePatterns: [(key: String, value: String)] = [
        // Key name patterns (case-insensitive partial match)
        ("key", ""), ("token", ""), ("secret", ""), ("password", ""),
        ("auth", ""), ("credential", ""), ("bearer", ""),
        // Value prefix patterns
        ("", "sk-"), ("", "sk_"), ("", "AKIA"), ("", "ghp_"),
        ("", "gho_"), ("", "ghs_"), ("", "github_pat_"),
        ("", "xoxb-"), ("", "xoxp-"), ("", "Bearer ")
    ]

    private func isSensitive(key: String, value: String) -> Bool {
        let lowerKey = key.lowercased()
        for pattern in Self.sensitivePatterns {
            if !pattern.key.isEmpty && lowerKey.contains(pattern.key) { return true }
            if !pattern.value.isEmpty && value.hasPrefix(pattern.value) { return true }
        }
        return false
    }

    private func maskedValue(_ value: String) -> String {
        guard value.count > 4 else { return "••••" }
        let suffix = String(value.suffix(4))
        return "••••••••\(suffix)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // Command Section
                sectionCard(title: "Command") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(server.command)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        if !server.args.isEmpty {
                            Text("Arguments:")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)

                            Text(server.args.joined(separator: " "))
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .textSelection(.enabled)
                }

                // Environment Variables Section
                if let env = server.env, !env.isEmpty {
                    let sortedKeys = env.keys.sorted()
                    sectionCard(title: "Environment Variables") {
                        VStack(spacing: theme.spacingSM) {
                            ForEach(sortedKeys, id: \.self) { key in
                                let value = env[key] ?? ""
                                let sensitive = isSensitive(key: key, value: value)
                                let revealed = revealedKeys.contains(key)

                                HStack {
                                    Text(key)
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)

                                    Spacer()

                                    if sensitive {
                                        Text(revealed ? value : maskedValue(value))
                                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                            .foregroundStyle(theme.textSecondary)
                                            .lineLimit(1)

                                        Button {
                                            if revealed {
                                                revealedKeys.remove(key)
                                                autoHideTasks[key]?.cancel()
                                                autoHideTasks[key] = nil
                                            } else {
                                                revealedKeys.insert(key)
                                                // Auto-hide after 5 seconds
                                                autoHideTasks[key]?.cancel()
                                                autoHideTasks[key] = Task {
                                                    try? await Task.sleep(for: .seconds(5))
                                                    if !Task.isCancelled {
                                                        await MainActor.run {
                                                            revealedKeys.remove(key)
                                                            autoHideTasks[key] = nil
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: revealed ? "eye.slash" : "eye")
                                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                                .foregroundStyle(theme.textTertiary)
                                                .frame(minWidth: 30, minHeight: 30)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(revealed ? "Hide \(key)" : "Reveal \(key)")
                                    } else {
                                        Text(value)
                                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                            .foregroundStyle(theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                // Configuration Section
                sectionCard(title: "Configuration") {
                    VStack(spacing: theme.spacingSM) {
                        HStack {
                            Text("Scope")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(server.scope.rawValue.capitalized)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }

                        Divider().background(theme.divider)

                        HStack {
                            Text("Status")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text(statusText)
                                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                    .foregroundStyle(statusColor)
                            }
                        }

                        if let configPath = server.configPath {
                            Divider().background(theme.divider)
                            HStack {
                                Text("Config Path")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text(configPath)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                // Full Command Section
                sectionCard(title: "Full Command") {
                    Text(fullCommand)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(server.name)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Copy command")
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(Capsule())
                    .padding(.bottom, theme.spacingLG)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showCopiedToast)
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text(title.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            content()
                .padding(theme.spacingMD)
                .modifier(GlassCard())
        }
    }

    // MARK: - Helpers

    private var fullCommand: String {
        if server.args.isEmpty {
            return server.command
        }
        return "\(server.command) \(server.args.joined(separator: " "))"
    }

    private var statusColor: Color {
        switch server.status {
        case .healthy: return theme.success
        case .unhealthy: return theme.error
        case .unknown: return theme.warning
        }
    }

    private var statusText: String {
        switch server.status {
        case .healthy: return "Healthy"
        case .unhealthy: return "Unhealthy"
        case .unknown: return "Unknown"
        }
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = fullCommand
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullCommand, forType: .string)
        #endif
        // SA-MED-4: ToastModifier handles auto-dismiss — no manual timer needed.
        showCopiedToast = true
    }
}
