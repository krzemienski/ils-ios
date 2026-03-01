import SwiftUI
import ILSShared

/// Scrollable message list with auto-scroll, lazy rendering, and user-scroll detection.
///
/// Renders the full conversation history using a `LazyVStack` inside a `ScrollViewReader`,
/// auto-scrolling to the bottom when new messages arrive or streaming begins — unless the
/// user has manually scrolled up. User-scroll detection is implemented via `DragGesture`
/// because SwiftUI provides no native callback for programmatic vs. user-initiated scroll.
///
/// When the user scrolls up during streaming a floating "jump to bottom" button appears.
/// Tapping it resets scroll state and jumps back to the latest content.
///
/// ## Topics
/// ### Input Properties
/// - ``messages`` - Ordered array of conversation messages to display
/// - ``isStreaming`` - Whether Claude is currently streaming a response
/// - ``isLoadingHistory`` - Whether prior message history is being fetched
/// - ``currentStreamingMessage`` - Partially-received assistant message, if any
/// - ``sessionProjectId`` - Project context passed to permission UI components
///
/// ### Bindings
/// - ``isUserScrolledUp`` - Tracks whether the user has manually scrolled away from the bottom
/// - ``showJumpToBottom`` - Controls visibility of the floating jump-to-bottom button
///
/// ### Callbacks
/// - ``onDeleteMessage`` - Called when the user requests a message be deleted
/// - ``onRetryMessage`` - Called when the user requests the last user turn be retried
///
/// ### Scroll Management
/// - ``scrollToBottom(proxy:)`` - Scrolls to the sentinel "bottom" anchor, respecting reduce-motion
/// - ``jumpToBottomButton(proxy:)`` - Floating FAB that resets scroll state and jumps to bottom
/// - ``showsTypingIndicator`` - Returns true while streaming and no text has arrived yet
struct ChatMessageList: View {
    /// Ordered array of messages to display in the conversation.
    let messages: [ChatMessage]
    /// Whether Claude is currently streaming a response.
    let isStreaming: Bool
    /// Whether prior message history is being loaded from the server.
    let isLoadingHistory: Bool
    /// Status text shown in the streaming indicator banner.
    let statusText: String?
    /// The partially-received assistant message currently being streamed, if any.
    let currentStreamingMessage: ChatMessage?
    /// Whether the user has manually scrolled up, suppressing auto-scroll to bottom.
    @Binding var isUserScrolledUp: Bool
    /// Whether the floating "jump to bottom" button is visible.
    @Binding var showJumpToBottom: Bool
    /// Called when the user chooses to delete a message via context menu.
    let onDeleteMessage: (ChatMessage) -> Void
    /// Called when the user chooses to retry a message via context menu.
    let onRetryMessage: (ChatMessage) -> Void
    /// Whether older messages are available to load.
    let canLoadMore: Bool
    /// Whether older messages are currently being fetched.
    let isLoadingMore: Bool
    /// Called when the user taps "Load earlier messages".
    let onLoadMore: () -> Void
    /// The encoded project path for the current session, used by permission UI.
    let sessionProjectId: String?

    /// Dynamic horizontal padding for messages, scales with the user's text size preference.
    @ScaledMetric(relativeTo: .body) private var messageSpacing: CGFloat = 16
    /// Vertical gap between messages from different senders.
    @ScaledMetric(relativeTo: .body) private var senderGap: CGFloat = 24
    /// Vertical gap between consecutive messages from the same sender.
    @ScaledMetric(relativeTo: .body) private var sameSenderGap: CGFloat = 8

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// On regular (iPad) size class, caps message content at a readable max width.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
                    // IPAD-CW: Cap readable content width at 800pt on regular (iPad) size class
                    // and center it. On compact (iPhone) size class this is a no-op.
                    .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)
                    .frame(maxWidth: .infinity)
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
            if canLoadMore {
                Button {
                    onLoadMore()
                } label: {
                    if isLoadingMore {
                        ProgressView()
                            .padding()
                    } else {
                        Label("Load earlier messages", systemImage: "arrow.up.circle")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                            .padding()
                    }
                }
                .disabled(isLoadingMore)
                .id("load-more")
            }

            // H-SP1: Use Array.enumerated() for O(1) prev-message lookup
            // instead of O(n) firstIndex(where:) which caused O(n²) per render.
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                let prevMessage: ChatMessage? = index > 0 ? messages[index - 1] : nil
                // System messages are never grouped with adjacent messages.
                let isSameSender = !message.isSystem
                    && !(prevMessage?.isSystem ?? false)
                    && prevMessage?.isUser == message.isUser

                if message.isSystem {
                    SystemMessageView(
                        message: message.text,
                        eventType: message.systemEventType ?? .generic
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                } else if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: onDeleteMessage
                    )
                    .equatable()
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
                    .equatable()
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, isSameSender ? sameSenderGap : senderGap)
                }
            }

            Group {
                if showsTypingIndicator {
                    TypingIndicatorBubble()
                        .padding(.horizontal, messageSpacing)
                        .padding(.top, messageSpacing)
                        .id("typing-indicator")
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showsTypingIndicator)

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding(.vertical, messageSpacing)
    }

    /// `true` while Claude is streaming but no tokens have been received yet,
    /// indicating the typing indicator should be shown.
    private var showsTypingIndicator: Bool {
        isStreaming && (currentStreamingMessage?.text.isEmpty ?? true)
    }

    /// Floating button that appears when the user scrolls up during streaming.
    /// Resets scroll state and animates back to the latest message.
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
                .font(.system(size: 28, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .background(Circle().fill(theme.bgSecondary))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Jump to bottom")
        .accessibilityHint("Scrolls to the most recent message")
    }

    /// Scrolls to the bottom sentinel view, using animation unless reduce-motion is enabled.
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
