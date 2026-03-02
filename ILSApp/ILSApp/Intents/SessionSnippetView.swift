import AppIntents
import SwiftUI

// MARK: - Snippet Theme Constants

private enum SnippetColors {
    static let background = "#030306"
    static let accent = "#00D4FF"
    static let success = "#00ff88"
    static let textSecondary = "#a0a0b0"
    static let textTertiary = "#9595b8"
}

// MARK: - Snippet Data Model

/// Lightweight session info for Siri snippet display.
/// Mirrors WidgetSessionInfo but without WidgetKit dependency.
@available(iOS 16.0, *)
struct SnippetSessionInfo: Identifiable {
    let id: String
    let name: String
    let model: String
    let messageCount: Int
    let isActive: Bool
    let projectName: String?

    /// Convenience initializer from a SessionEntity (isActive defaults to false when unknown).
    init(from entity: SessionEntity, isActive: Bool = false) {
        self.id = entity.id
        self.name = entity.name
        self.model = entity.model
        self.messageCount = entity.messageCount
        self.isActive = isActive
        self.projectName = entity.projectName
    }

    init(
        id: String,
        name: String,
        model: String,
        messageCount: Int,
        isActive: Bool,
        projectName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.messageCount = messageCount
        self.isActive = isActive
        self.projectName = projectName
    }
}

// MARK: - Session Snippet View

/// Rich SwiftUI snippet view for Siri and Shortcuts.
///
/// Used by `ListSessionsIntent` (list mode) and `GetSessionInfoIntent` (detail mode)
/// as the `snippetView` in their intent results.
@available(iOS 16.0, *)
struct SessionSnippetView: View {
    let mode: Mode

    enum Mode {
        /// Shows up to five sessions in a compact list layout.
        case list([SnippetSessionInfo])
        /// Shows detailed info for a single session.
        case detail(SnippetSessionInfo)
    }

    var body: some View {
        switch mode {
        case .list(let sessions):
            SessionListSnippetView(sessions: sessions)
        case .detail(let session):
            SessionDetailSnippetView(session: session)
        }
    }
}

// MARK: - Session List Snippet

@available(iOS 16.0, *)
private struct SessionListSnippetView: View {
    let sessions: [SnippetSessionInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: SnippetColors.accent))
                Text("Recent Sessions")
                    .font(.footnote.weight(.bold).monospaced())
                    .foregroundColor(.white)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundColor(Color(hex: SnippetColors.textSecondary))
            }

            if sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(.title3)
                            .foregroundColor(Color(hex: SnippetColors.textTertiary))
                        Text("No sessions")
                            .font(.caption.monospaced())
                            .foregroundColor(Color(hex: SnippetColors.textTertiary))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(sessions.prefix(5))) { session in
                    SessionSnippetRow(session: session)
                }
            }
        }
        .padding(12)
        .background(Color(hex: SnippetColors.background))
        .cornerRadius(12)
    }
}

// MARK: - Session Detail Snippet

@available(iOS 16.0, *)
private struct SessionDetailSnippetView: View {
    let session: SnippetSessionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + status header
            HStack(spacing: 6) {
                Circle()
                    .fill(session.isActive
                          ? Color(hex: SnippetColors.success)
                          : Color(hex: SnippetColors.textTertiary))
                    .frame(width: 8, height: 8)
                Text(session.name)
                    .font(.footnote.weight(.bold).monospaced())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }

            // Detail field rows
            VStack(alignment: .leading, spacing: 4) {
                SnippetDetailRow(label: "Model", value: session.model.uppercased())
                SnippetDetailRow(label: "Messages", value: "\(session.messageCount)")
                if let project = session.projectName, !project.isEmpty {
                    SnippetDetailRow(label: "Project", value: project)
                }
                SnippetDetailRow(label: "Status", value: session.isActive ? "Active" : "Idle")
            }
        }
        .padding(12)
        .background(Color(hex: SnippetColors.background))
        .cornerRadius(12)
    }
}

// MARK: - Shared Row Subviews

@available(iOS 16.0, *)
private struct SessionSnippetRow: View {
    let session: SnippetSessionInfo

    var body: some View {
        HStack(spacing: 8) {
            // Active status indicator
            Circle()
                .fill(session.isActive
                      ? Color(hex: SnippetColors.success)
                      : Color(hex: SnippetColors.textTertiary))
                .frame(width: 6, height: 6)

            // Session name
            Text(session.name)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Model badge
            Text(session.model.uppercased())
                .font(.caption2.weight(.bold).monospaced())
                .foregroundColor(Color(hex: SnippetColors.accent))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: SnippetColors.accent).opacity(0.15))
                )

            // Message count
            HStack(spacing: 2) {
                Image(systemName: "message.fill")
                    .font(.caption2)
                Text("\(session.messageCount)")
                    .font(.caption2.weight(.medium).monospaced())
            }
            .foregroundColor(Color(hex: SnippetColors.textSecondary))
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 16.0, *)
private struct SnippetDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundColor(Color(hex: SnippetColors.textSecondary))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium).monospaced())
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}
