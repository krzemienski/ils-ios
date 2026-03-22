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
/// Non-system messages support a long-press context menu with Bookmark, Copy, and Share
/// actions. Bookmarked messages display a bookmark indicator in their top-trailing corner.
/// Tapping Bookmark opens ``BookmarkMessageSheet`` for adding a note and tags.
///
/// ## Topics
/// ### Input Properties
/// - ``messages`` - Ordered array of conversation messages to display
/// - ``isStreaming`` - Whether Claude is currently streaming a response
/// - ``isLoadingHistory`` - Whether prior message history is being fetched
/// - ``currentStreamingMessage`` - Partially-received assistant message, if any
/// - ``sessionId`` - UUID of the current session, required for bookmark creation
/// - ``sessionName`` - Display name of the session, shown in the bookmark sheet
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
    /// UUID of the current session, used when creating bookmarks.
    let sessionId: UUID
    /// Display name of the current session, shown in the bookmark sheet.
    let sessionName: String?

    /// Dynamic horizontal padding for messages, scales with the user's text size preference.
    @ScaledMetric(relativeTo: .body) private var messageSpacing: CGFloat = 16
    /// Vertical gap between messages from different senders.
    @ScaledMetric(relativeTo: .body) private var senderGap: CGFloat = 24
    /// Vertical gap between consecutive messages from the same sender.
    @ScaledMetric(relativeTo: .body) private var sameSenderGap: CGFloat = 8

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Adaptive layout size class driven by actual window width, not just system size class.
    /// Properly reflects iPad multitasking widths (1/3 Split View, Slide Over, etc.).
    @Environment(\.layoutSizeClass) private var layoutSizeClass

    /// Maximum readable content width based on the adaptive layout size class.
    /// - narrow (< 500pt): no cap — use full available width
    /// - regular (500–900pt): 700pt cap for comfortable reading
    /// - wide (> 900pt): 800pt cap matching typical desktop reading width
    private var maxContentWidth: CGFloat {
        switch layoutSizeClass {
        case .narrow:
            return .infinity
        case .regular:
            return 700
        case .wide:
            return 800
        }
    }

    /// The message currently being bookmarked — non-nil triggers `BookmarkMessageSheet`.
    @State private var messageToBookmark: ChatMessage?
    /// Message IDs for which the key moment suggestion banner has been dismissed.
    @State private var dismissedKeyMomentIds: Set<UUID> = []

    /// Shared bookmark manager for state queries and mutation.
    private let bookmarksManager = MessageBookmarksManager.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesContent
                    // IPAD-CW: Cap readable content width based on adaptive layout class.
                    // Scales from full-width at narrow (Slide Over, 1/3 Split) to 800pt
                    // at wide (full-screen iPad). Centers within the scroll view.
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
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
        .sheet(item: $messageToBookmark) { message in
            BookmarkMessageSheet(
                messageId: message.id.uuidString,
                sessionId: sessionId,
                sessionName: sessionName,
                messageContent: message.text,
                messageRole: message.isUser ? "user" : "assistant"
            )
            .environment(\.theme, theme)
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
                .accessibilityLabel(isLoadingMore ? "Loading earlier messages" : "Load earlier messages")
                .accessibilityIdentifier("load-more-button")
                .id("load-more")
            }

            // H-SP1: Use zip(indices, messages) for O(1) prev-message lookup
            // instead of O(n) firstIndex(where:) which caused O(n²) per render.
            // SPERF-MED-6: zip avoids the intermediate Array allocation of enumerated().
            ForEach(Array(zip(messages.indices, messages)), id: \.1.id) { index, message in
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
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, messageSpacing)
                } else if message.isUser {
                    UserMessageCard(
                        message: message,
                        onDelete: onDeleteMessage
                    )
                    .equatable()
                    .overlay(alignment: .topTrailing) {
                        bookmarkIndicator(for: message)
                    }
                    .contextMenu {
                        bookmarkMenuItems(for: message)
                    }
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, isSameSender ? sameSenderGap : senderGap)

                    keyMomentBanner(for: message)
                } else {
                    AssistantCard(
                        message: message,
                        onRetry: { msg in
                            onRetryMessage(msg)
                        },
                        onDelete: onDeleteMessage
                    )
                    .equatable()
                    .overlay(alignment: .topTrailing) {
                        bookmarkIndicator(for: message)
                    }
                    .contextMenu {
                        bookmarkMenuItems(for: message)
                    }
                    .padding(.horizontal, messageSpacing)
                    .padding(.top, isSameSender ? sameSenderGap : senderGap)

                    keyMomentBanner(for: message)
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

    /// Small bookmark icon shown in the top-trailing corner of a bookmarked message bubble.
    @ViewBuilder
    private func bookmarkIndicator(for message: ChatMessage) -> some View {
        if bookmarksManager.isBookmarked(messageId: message.id.uuidString) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .padding(6)
                .accessibilityLabel("Bookmarked")
                .accessibilityHint("This message is saved to your bookmarks")
        }
    }

    /// Context menu items for a non-system message: Bookmark/Remove Bookmark, Copy, Share.
    @ViewBuilder
    private func bookmarkMenuItems(for message: ChatMessage) -> some View {
        let messageIdString = message.id.uuidString
        let isAlreadyBookmarked = bookmarksManager.isBookmarked(messageId: messageIdString)

        if isAlreadyBookmarked {
            Button(role: .destructive) {
                Task { await bookmarksManager.removeBookmark(messageId: messageIdString) }
            } label: {
                Label("Remove Bookmark", systemImage: "bookmark.slash")
            }
        } else {
            Button {
                messageToBookmark = message
            } label: {
                Label("Bookmark", systemImage: "bookmark")
            }
        }

        Divider()

        Button {
            #if os(iOS)
            UIPasteboard.general.string = message.text
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
            #endif
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if !message.text.isEmpty {
            ShareLink(item: message.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    /// Inline key moment suggestion chip shown below a message when the heuristic
    /// detector flags it as a potential key moment.
    ///
    /// The banner is suppressed when:
    /// - The message has already been bookmarked.
    /// - The user has dismissed it for this message in the current session.
    /// - The platform is not iOS.
    ///
    /// Tapping the star quick-saves the bookmark without opening the sheet.
    /// Tapping × dismisses the banner for the current session.
    @ViewBuilder
    private func keyMomentBanner(for message: ChatMessage) -> some View {
        let suggestion = KeyMomentsDetector.analyze(message)
        let isAlreadyBookmarked = bookmarksManager.isBookmarked(messageId: message.id.uuidString)
        let isDismissed = dismissedKeyMomentIds.contains(message.id)

        if let suggestion, !isAlreadyBookmarked, !isDismissed {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "star.fill")
                    .font(.system(size: theme.fontCaption, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text("Bookmark this key moment?")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    Task {
                        await bookmarksManager.addBookmark(
                            messageId: message.id.uuidString,
                            sessionId: sessionId,
                            sessionName: sessionName,
                            messageContent: message.text,
                            messageRole: message.isUser ? "user" : "assistant",
                            note: suggestion.reason
                        )
                    }
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: theme.fontCaption, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save key moment bookmark")
                .accessibilityHint(suggestion.reason)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = dismissedKeyMomentIds.insert(message.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.fontCaption, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss key moment suggestion")
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
            .background(theme.accent.opacity(0.08) as Color)
            .overlay(alignment: .leading) {
                Rectangle()
                    .frame(width: 2)
                    .foregroundStyle(theme.accent.opacity(0.5) as Color)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .padding(.horizontal, messageSpacing)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Key moment suggestion: \(suggestion.reason)")
        }
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
                .font(.system(size: theme.fontTitle1, design: theme.fontDesign))
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
        .accessibilityIdentifier("jump-to-bottom-button")
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

// MARK: - Preview

#Preview {
    @Previewable @State var isUserScrolledUp = false
    @Previewable @State var showJumpToBottom = false
    ChatMessageList(
        messages: [],
        isStreaming: false,
        isLoadingHistory: false,
        statusText: nil,
        currentStreamingMessage: nil,
        isUserScrolledUp: $isUserScrolledUp,
        showJumpToBottom: $showJumpToBottom,
        onDeleteMessage: { _ in },
        onRetryMessage: { _ in },
        canLoadMore: false,
        isLoadingMore: false,
        onLoadMore: {},
        sessionProjectId: nil,
        sessionId: UUID(),
        sessionName: "Preview Session"
    )
}
