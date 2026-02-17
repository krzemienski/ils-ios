import SwiftUI
import ILSShared

// MARK: - MCP Server Detail View (extracted from MCPServerListView.swift, migrated to theme)

struct MCPServerDetailView: View {
    let server: MCPServer
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCopiedToast = false

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

                            Text(server.args.map { maskSensitiveValue($0) }.joined(separator: " "))
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
                                HStack {
                                    Text(key)
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)

                                    Spacer()

                                    Text(maskEnvValue(key: key, value: env[key] ?? ""))
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
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

    /// Patterns that indicate a value is sensitive and should be masked.
    private static let sensitivePatterns: [String] = [
        "key", "token", "secret", "password", "credential", "auth",
        "api_key", "apikey", "api-key", "bearer", "ghp_", "sk-", "ghu_"
    ]

    /// Mask a value if it looks like a secret (long alphanumeric string or matches sensitive patterns).
    private func maskSensitiveValue(_ value: String) -> String {
        let lower = value.lowercased()
        let looksLikeToken = value.count > 20 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let matchesPattern = Self.sensitivePatterns.contains { lower.contains($0) }

        if looksLikeToken || matchesPattern {
            let prefix = String(value.prefix(4))
            return "\(prefix)****"
        }
        return value
    }

    /// Mask environment variable value if the key or value suggests it's sensitive.
    private func maskEnvValue(key: String, value: String) -> String {
        let lowerKey = key.lowercased()
        let isSensitiveKey = Self.sensitivePatterns.contains { lowerKey.contains($0) }
        if isSensitiveKey {
            let prefix = String(value.prefix(4))
            return value.count > 4 ? "\(prefix)****" : "****"
        }
        return maskSensitiveValue(value)
    }

    private var fullCommand: String {
        if server.args.isEmpty {
            return server.command
        }
        let maskedArgs = server.args.map { maskSensitiveValue($0) }
        return "\(server.command) \(maskedArgs.joined(separator: " "))"
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
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showCopiedToast = false
            }
        }
    }
}
