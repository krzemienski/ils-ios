import SwiftUI
import ILSShared

/// Chat-style interface for reading and sending messages within a team.
///
/// Displays the team's message history as directional bubbles (lead messages
/// appear on the right, teammate messages on the left), and provides an input bar
/// for composing new messages. Messages are loaded on appearance and sent via
/// ``TeamsViewModel``.
///
/// ## Key State
/// - ``teamName`` - Identifies which team's message thread to display
/// - ``messageText`` - Current contents of the message compose field
/// - ``recipient`` - Optional targeted recipient name; empty means broadcast to all
struct TeamMessagesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: TeamsViewModel
    let teamName: String
    @State private var messageText = ""
    @State private var recipient = ""
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: theme.spacingSM) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                    }
                }
                .padding(theme.spacingMD)
            }

            inputBar
        }
        .task {
            await viewModel.loadMessages(teamName: teamName)
        }
    }

    private func messageBubble(_ message: TeamMessage) -> some View {
        let isFromLead = message.from.lowercased() == "lead"

        return HStack {
            if isFromLead { Spacer() }

            VStack(alignment: isFromLead ? .trailing : .leading, spacing: theme.spacingSM) {
                Text(message.from)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Text(message.content)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .padding(theme.spacingSM)
                    .background(
                        (isFromLead ? theme.accent : theme.bgSecondary)
                            .opacity(isFromLead ? 0.2 : 1.0)
                    )
                    .cornerRadius(theme.cornerRadius)

                if let timestamp = message.timestamp {
                    Text(formatTimestamp(timestamp))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .frame(maxWidth: 280, alignment: isFromLead ? .trailing : .leading)

            if !isFromLead { Spacer() }
        }
    }

    private var inputBar: some View {
        HStack(spacing: theme.spacingSM) {
            TextField("Message...", text: $messageText)
                .focused($isMessageFocused)
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .focusRing(isFocused: isMessageFocused, cornerRadius: theme.cornerRadius)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(messageText.isEmpty ? theme.textTertiary : theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.bgSecondary)
                    .cornerRadius(theme.cornerRadius)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(theme.spacingMD)
        .background(theme.bgPrimary)
    }

    private func sendMessage() {
        let content = messageText
        messageText = ""

        Task {
            await viewModel.sendMessage(
                teamName: teamName,
                content: content,
                to: recipient.isEmpty ? nil : recipient,
                from: "lead"
            )
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        DateFormatters.time.string(from: date)
    }
}
