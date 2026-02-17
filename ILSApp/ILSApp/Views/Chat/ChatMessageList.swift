import SwiftUI
import ILSShared

struct ChatMessageList: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let isLoadingHistory: Bool
    let statusText: String?
    let currentStreamingMessage: ChatMessage?
    @Binding var isUserScrolledUp: Bool
    @Binding var showJumpToBottom: Bool
    let onDeleteMessage: (ChatMessage) -> Void
    let onRetryMessage: (ChatMessage) -> Void
    let sessionProjectId: String?

    @ScaledMetric(relativeTo: .body) private var messageSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var senderGap: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var sameSenderGap: CGFloat = 8

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
            }
            .onChange(of: messages.count) { oldCount, newCount in
                let isNewMessage = oldCount > 0 && newCount == oldCount + 1
                if isNewMessage && !isUserScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: isStreaming) { _, streaming in
                if streaming && !isUserScrolledUp {
                    scrollToBottom(proxy: proxy)
                }
                if !streaming {
                    if reduceMotion {
                        showJumpToBottom = false
                    } else {
                        withAnimation { showJumpToBottom = false }
                    }
                }
            }
            .onChange(of: isLoadingHistory) { wasLoading, isLoading in
                if wasLoading && !isLoading && !messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { gesture in
                    if gesture.translation.height > 10 {
                        isUserScrolledUp = true
                        if isStreaming {
                            if reduceMotion {
                                showJumpToBottom = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showJumpToBottom = true
                                }
                            }
                        }
                    }
                }
            )
            .overlay(alignment: .bottomTrailing) {
                if showJumpToBottom {
                    jumpToBottomButton(proxy: proxy)
                }
            }
        }
    }

    private var messagesContent: some View {
        LazyVStack(spacing: 0) {
            if messages.isEmpty && !isLoadingHistory && !isStreaming {
                emptyChatState
            }

            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                let prevMessage: ChatMessage? = index > 0 ? messages[index - 1] : nil
                let isSameSender = prevMessage?.isUser == message.isUser

                if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: onDeleteMessage
                    )
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, isSameSender ? sameSenderGap : senderGap)
                } else {
                    AssistantCard(
                        message: message,
                        onRetry: { msg in
                            onRetryMessage(msg)
                        },
                        onDelete: onDeleteMessage
                    )
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, isSameSender ? sameSenderGap : senderGap)
                }
            }

            if shouldShowTypingIndicator() {
                StreamingIndicatorView(
                    statusText: statusText
                )
                .padding(.horizontal, messageSpacing)
                .padding(.top, messageSpacing)
                .id("typing-indicator")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding(.vertical, messageSpacing)
    }

    private var emptyChatState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("Start a Conversation")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("Send a message to begin chatting with Claude")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty chat. Send a message to begin.")
    }

    private func shouldShowTypingIndicator() -> Bool {
        isStreaming && (currentStreamingMessage?.text.isEmpty ?? true)
    }

    private func jumpToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            isUserScrolledUp = false
            if reduceMotion {
                showJumpToBottom = false
            } else {
                withAnimation { showJumpToBottom = false }
            }
            scrollToBottom(proxy: proxy)
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(.title2, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .background(Circle().fill(theme.bgSecondary))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .padding(.trailing, messageSpacing)
        .padding(.bottom, messageSpacing)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Jump to bottom")
        .accessibilityHint("Scrolls to the most recent message")
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
