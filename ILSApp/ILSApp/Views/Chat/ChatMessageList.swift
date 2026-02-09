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
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                let prevMessage: ChatMessage? = index > 0 ? messages[index - 1] : nil
                let isSameSender = prevMessage?.isUser == message.isUser

                if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: onDeleteMessage
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, isSameSender ? 8 : 24)
                } else {
                    AssistantCard(
                        message: message,
                        onRetry: { msg in
                            onRetryMessage(msg)
                        },
                        onDelete: onDeleteMessage
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, isSameSender ? 8 : 24)
                }
            }

            if shouldShowTypingIndicator() {
                StreamingIndicatorView(
                    statusText: statusText
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .id("typing-indicator")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding(.vertical, 16)
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
                .font(.system(size: 28))
                .foregroundStyle(theme.accent)
                .background(Circle().fill(theme.bgSecondary))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Jump to bottom")
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
