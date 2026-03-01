import SwiftUI
import ILSShared

// MARK: - MCP Server Detail View (extracted from MCPServerListView.swift, migrated to theme)

struct MCPServerDetailView: View {
    let server: MCPServer
    var viewModel: MCPViewModel
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCopiedToast = false
    @State private var revealedKeys: Set<String> = []
    @State private var autoHideTasks: [String: Task<Void, Never>] = [:]
    @State private var isToggling = false
    @State private var showEditSheet = false

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

    /// Live server looked up from viewModel so SwiftUI re-renders on state changes.
    private var liveServer: MCPServer {
        viewModel.servers.first(where: { $0.id == server.id }) ?? server
    }

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

                        Divider().background(theme.divider)

                        HStack {
                            if isToggling {
                                Toggle(isOn: .constant(liveServer.isEnabled)) {
                                    Text("Enabled")
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)
                                }
                                .tint(theme.accent)
                                .disabled(true)
                                Spacer()
                                ProgressView()
                                    .tint(theme.accent)
                                    .scaleEffect(0.8)
                            } else {
                                Toggle(isOn: Binding(
                                    get: { liveServer.isEnabled },
                                    set: { _ in
                                        HapticManager.selection()
                                        isToggling = true
                                        Task {
                                            await viewModel.toggleEnabled(server)
                                            isToggling = false
                                        }
                                    }
                                )) {
                                    Text("Enabled")
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)
                                }
                                .tint(theme.accent)
                                .accessibilityLabel(liveServer.isEnabled ? "Disable \(server.name)" : "Enable \(server.name)")
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

                // Actions Section
                sectionCard(title: "Actions") {
                    VStack(spacing: 0) {
                        NavigationLink {
                            MCPLogsView(server: server, viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 24)
                                Text("View Logs")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View logs for \(server.name)")

                        Divider().background(theme.divider).padding(.vertical, theme.spacingXS)

                        NavigationLink {
                            MCPTroubleshootView(server: server, viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver")
                                    .foregroundStyle(theme.warning)
                                    .frame(width: 24)
                                Text("Troubleshoot")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Troubleshoot \(server.name)")
                    }
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
                    showEditSheet = true
                } label: {
                    Text("Edit")
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Edit \(server.name)")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Copy command")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                MCPAddEditView(viewModel: viewModel, server: server)
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
        switch liveServer.status {
        case .healthy: return theme.success
        case .unhealthy: return theme.error
        case .unknown: return theme.warning
        }
    }

    private var statusText: String {
        switch liveServer.status {
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
