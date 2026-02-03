import SwiftUI
import ILSShared

// MARK: - Template Model

struct MCPTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let command: String
    let args: [String]
    let envVars: [String]
    let category: String

    var displayCommand: String {
        if args.isEmpty {
            return command
        }
        return "\(command) \(args.joined(separator: " "))"
    }
}

// MARK: - Templates View

struct MCPTemplatesView: View {
    let onSelectTemplate: (MCPTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let templates: [MCPTemplate] = [
        // File System
        MCPTemplate(
            name: "Filesystem",
            icon: "folder.fill",
            description: "Read and write files on your local filesystem. Enables Claude to access project files.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"],
            envVars: [],
            category: "Development"
        ),

        // GitHub
        MCPTemplate(
            name: "GitHub",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "Access GitHub repositories, issues, PRs, and more. Requires a GitHub personal access token.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            envVars: ["GITHUB_TOKEN"],
            category: "Development"
        ),

        // PostgreSQL
        MCPTemplate(
            name: "PostgreSQL",
            icon: "cylinder.fill",
            description: "Query and manage PostgreSQL databases. Requires database connection string.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres"],
            envVars: ["POSTGRES_CONNECTION_STRING"],
            category: "Database"
        ),

        // Slack
        MCPTemplate(
            name: "Slack",
            icon: "bubble.left.and.bubble.right.fill",
            description: "Send messages and interact with Slack workspaces. Requires Slack API token.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-slack"],
            envVars: ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID"],
            category: "Communication"
        ),

        // Memory
        MCPTemplate(
            name: "Memory",
            icon: "brain.head.profile",
            description: "Persistent memory storage for Claude. Enables Claude to remember information across sessions.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"],
            envVars: [],
            category: "Productivity"
        ),

        // Puppeteer
        MCPTemplate(
            name: "Puppeteer",
            icon: "network",
            description: "Web scraping and browser automation. Enables Claude to interact with web pages.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-puppeteer"],
            envVars: [],
            category: "Automation"
        ),

        // Google Drive
        MCPTemplate(
            name: "Google Drive",
            icon: "externaldrive.fill",
            description: "Access and manage Google Drive files. Requires Google OAuth credentials.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-gdrive"],
            envVars: ["GDRIVE_CLIENT_ID", "GDRIVE_CLIENT_SECRET"],
            category: "Storage"
        ),

        // AWS
        MCPTemplate(
            name: "AWS",
            icon: "cloud.fill",
            description: "Interact with AWS services (S3, EC2, Lambda, etc). Requires AWS credentials.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-aws"],
            envVars: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"],
            category: "Cloud"
        ),

        // Git
        MCPTemplate(
            name: "Git",
            icon: "arrow.triangle.branch",
            description: "Git repository operations. Read commits, diffs, and manage branches.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-git"],
            envVars: [],
            category: "Development"
        ),

        // Brave Search
        MCPTemplate(
            name: "Brave Search",
            icon: "magnifyingglass",
            description: "Web search powered by Brave Search API. Requires Brave Search API key.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            envVars: ["BRAVE_API_KEY"],
            category: "Search"
        ),

        // Docker
        MCPTemplate(
            name: "Docker",
            icon: "cube.fill",
            description: "Manage Docker containers and images. List, start, stop, and inspect containers.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-docker"],
            envVars: [],
            category: "Development"
        ),

        // SQLite
        MCPTemplate(
            name: "SQLite",
            icon: "tray.full.fill",
            description: "Query and manage SQLite databases. Lightweight local database access.",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sqlite", "/path/to/database.db"],
            envVars: [],
            category: "Database"
        )
    ]

    private var filteredTemplates: [MCPTemplate] {
        if searchText.isEmpty {
            return templates
        }
        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(searchText) ||
            template.description.localizedCaseInsensitiveContains(searchText) ||
            template.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTemplates: [(String, [MCPTemplate])] {
        let grouped = Dictionary(grouping: filteredTemplates) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredTemplates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(groupedTemplates, id: \.0) { category, categoryTemplates in
                        Section(category) {
                            ForEach(categoryTemplates) { template in
                                Button {
                                    onSelectTemplate(template)
                                    dismiss()
                                } label: {
                                    MCPTemplateRowView(template: template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("MCP Templates")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Template Row View

struct MCPTemplateRowView: View {
    let template: MCPTemplate

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: ILSTheme.cornerRadiusM)
                    .fill(ILSTheme.accent.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: template.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ILSTheme.accent)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(ILSTheme.headlineFont)
                    .foregroundColor(ILSTheme.primaryText)

                Text(template.description)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    // Command preview
                    Text(template.command)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ILSTheme.tertiaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusS)

                    // Environment variables badge
                    if !template.envVars.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 9))
                            Text("\(template.envVars.count) env")
                        }
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ILSTheme.warning.opacity(0.1))
                        .cornerRadius(ILSTheme.cornerRadiusS)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ILSTheme.tertiaryText)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    MCPTemplatesView { template in
        print("Selected template: \(template.name)")
    }
}
