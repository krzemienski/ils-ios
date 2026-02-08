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

    @Environment(\.theme) private var theme: any AppTheme

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
                    withAnimation { showJumpToBottom = false }
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
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showJumpToBottom = true
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
        LazyVStack(alignment: .leading, spacing: theme.spacingMD) {
            ForEach(messages) { message in
                if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: onDeleteMessage
                    )
                } else {
                    AssistantCard(
                        message: message,
                        onRetry: { msg in
                            onRetryMessage(msg)
                        },
                        onDelete: onDeleteMessage
                    )
                }
            }

            if shouldShowTypingIndicator() {
                StreamingIndicatorView(
                    statusText: statusText
                )
                .id("typing-indicator")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding()
    }

    private func shouldShowTypingIndicator() -> Bool {
        isStreaming && (currentStreamingMessage?.text.isEmpty ?? true)
    }

    private func jumpToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            isUserScrolledUp = false
            withAnimation { showJumpToBottom = false }
            scrollToBottom(proxy: proxy)
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.accent)
                .background(Circle().fill(theme.bgSecondary))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .padding(.trailing, theme.spacingMD)
        .padding(.bottom, theme.spacingMD)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Jump to bottom")
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}
