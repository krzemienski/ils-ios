import SwiftUI
import ILSShared

// MARK: - MCP Install Wizard View

/// Installation wizard for a curated MCP server from the marketplace.
///
/// Guides the user through configuring and installing an MCP server:
/// - Shows server metadata (icon, name, description, category, stars)
/// - Pre-fills the command and args from the marketplace entry
/// - Collects required environment variables via text fields
/// - Lets the user choose a configuration scope (user / project / local)
/// - Calls `MCPViewModel.installFromMarketplace()` and shows install progress
struct MCPInstallWizardView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let entry: MCPMarketplaceEntry
    var mcpVM: MCPViewModel

    @State private var envValues: [String: String] = [:]
    @State private var selectedScope = "user"
    @State private var installState: InstallState = .idle

    enum InstallState {
        case idle
        case installing
        case installed
        case failed(String)
    }

    private let scopeOptions = ["user", "project", "local"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                headerSection
                commandPreviewSection
                if !entry.requiredEnvVars.isEmpty {
                    envVarsSection
                }
                scopeSection
                installSection
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Install \(entry.name)")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .onAppear {
            for spec in entry.requiredEnvVars where envValues[spec.key] == nil {
                envValues[spec.key] = ""
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: theme.spacingMD) {
            // MCP server icon
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.entityMCP.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "server.rack")
                    .font(.system(size: theme.fontTitle3))
                    .foregroundStyle(theme.entityMCP)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if let description = entry.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: theme.spacingSM) {
                    // Category badge
                    Text(entry.category)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.entityMCP)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.entityMCP.opacity(0.15))
                        .clipShape(Capsule())

                    // Stars
                    if entry.stars > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                            Text("\(entry.stars)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    if entry.isStaffPick {
                        Text("Staff Pick")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.warning.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Command Preview

    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Command")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "terminal")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.entityMCP)
                        .frame(width: 20)
                    Text(entry.command)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                }

                if !entry.args.isEmpty {
                    HStack(alignment: .top, spacing: theme.spacingSM) {
                        Text("Args:")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .frame(width: 36, alignment: .leading)
                        Text(entry.args.joined(separator: " "))
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }

                Text(entry.repository)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Environment Variables

    private var envVarsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Configuration")

            VStack(spacing: 0) {
                ForEach(entry.requiredEnvVars) { spec in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: theme.spacingSM) {
                            Text(spec.key)
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            if spec.isRequired {
                                Text("Required")
                                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                                    .foregroundStyle(theme.error)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.error.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Spacer()
                        }

                        if !spec.description.isEmpty {
                            Text(spec.description)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }

                        TextField(
                            spec.placeholder ?? spec.key,
                            text: Binding(
                                get: { envValues[spec.key] ?? "" },
                                set: { envValues[spec.key] = $0 }
                            )
                        )
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                    }
                    .padding(theme.spacingMD)

                    if spec.id != entry.requiredEnvVars.last?.id {
                        Divider()
                            .background(theme.divider)
                    }
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Scope Picker

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionTitle("Scope")

            Picker("Scope", selection: $selectedScope) {
                ForEach(scopeOptions, id: \.self) { scope in
                    Text(scope.capitalized).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(theme.spacingSM)
            .modifier(GlassCard())
        }
    }

    // MARK: - Install Section

    @ViewBuilder
    private var installSection: some View {
        switch installState {
        case .idle:
            Button {
                Task { await performInstall() }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Install MCP Server")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .background(canInstall ? theme.accent : theme.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canInstall)

        case .installing:
            HStack(spacing: theme.spacingSM) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(theme.accent)
                Text("Installing...")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingMD)
            .modifier(GlassCard())

        case .installed:
            VStack(spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text("Successfully Installed")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.success)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .modifier(GlassCard())

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingMD)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .buttonStyle(.plain)
            }

        case .failed(let errorMessage):
            VStack(spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.error)
                    Text("Install Failed")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                }

                Text(errorMessage)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await performInstall() }
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingMD)
            .background(theme.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    // MARK: - Helpers

    /// Returns true when all required env vars have non-empty values.
    private var canInstall: Bool {
        for spec in entry.requiredEnvVars where spec.isRequired {
            let value = envValues[spec.key] ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        return true
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .tracking(1.2)
    }

    // MARK: - Actions

    private func performInstall() async {
        installState = .installing

        // Wrap the marketplace entry as a GitHubSearchResult for the existing API
        let result = GitHubSearchResult(
            repository: entry.repository,
            name: entry.name,
            description: entry.description,
            stars: entry.stars
        )

        // Only pass env vars that have non-empty values
        let filteredEnv = envValues.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let envToSend: [String: String]? = filteredEnv.isEmpty ? nil : filteredEnv

        let success = await mcpVM.installFromMarketplace(
            result: result,
            command: entry.command,
            args: entry.args,
            env: envToSend,
            scope: selectedScope
        )

        if success {
            installState = .installed
            HapticManager.impact(.medium)
        } else {
            let errorMsg = mcpVM.error?.localizedDescription ?? "Unknown error occurred"
            installState = .failed(errorMsg)
        }
    }
}
