import SwiftUI
import ILSShared

// MARK: - View Components

extension ChatView {

    // MARK: - Toolbar

    /// ChatToolbar wired with all action callbacks.
    @ToolbarContentBuilder
    var chatToolbar: some ToolbarContent {
        ChatToolbar(
            session: session,
            multiSessionVM: multiSessionVM,
            onBack: onBack,
            horizontalSizeClass: horizontalSizeClass,
            onRename: {
                actions.renameText = session.name ?? ""
                sheetDestination = .renameSession
            },
            onFork: {
                Task {
                    if let forked = await viewModel.forkSession() {
                        actions.forkedSession = forked
                        sheetDestination = .forkAlert
                    }
                }
            },
            onForkTree: { actions.navigateToForkTree = session },
            onSessionMemory: { sheetDestination = .sessionMemory },
            onExport: { sheetDestination = .exportSheet },
            onInfo: { sheetDestination = .sessionInfo },
            onDelete: { sheetDestination = .deleteSession },
            onSearch: {
                viewModel.isSearchActive = true
                showSearch = true
            },
            onPinToggle: {
                if multiSessionVM.isPinned(session) {
                    multiSessionVM.unpinSession(session)
                } else {
                    multiSessionVM.pinSession(session)
                }
                HapticManager.selection()
            }
        )
    }

    // MARK: - Keyboard Shortcuts Overlay

    /// Zero-size overlay providing keyboard shortcut bindings.
    var keyboardShortcutsOverlay: some View {
        ZStack {
            Button("Open Command Palette") { sheetDestination = .commandPalette }
                .keyboardShortcut("k", modifiers: .command)
            Button("Cancel Streaming") { viewModel.cancel() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Main Content

    /// Top-level layout stacking the status banner, offline banner, context window bar,
    /// related-sessions panel, message list, divider, and input bar.
    var mainContent: some View {
        VStack(spacing: 0) {
            if showSearch {
                inlineSearchBar
                theme.divider.frame(height: 0.5)
                searchResultsView
            } else {
                statusBanner
                compactionAlertBanner
                OfflineIndicator(isOffline: viewModel.isOffline)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.3),
                        value: viewModel.isOffline
                    )
                contextWindowBar
                relatedSessionsPanel
                messageList
                theme.divider.frame(height: 0.5)
                #if os(iOS)
                if speechService.isRecording {
                    VoiceInputOverlay(
                        transcribedText: .init(
                            get: { speechService.transcribedText },
                            set: { _ in }
                        ),
                        audioLevel: CGFloat(speechService.audioLevel),
                        onDone: { text in
                            speechService.stopRecording()
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if inputText.isEmpty {
                                    inputText = text
                                } else {
                                    inputText += " " + text
                                }
                                isInputFocused = true
                            }
                        },
                        onCancel: { speechService.cancelRecording() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                #endif
                quickReplyToolbar
                bottomBar
            }
        }
        #if os(iOS)
        .animation(.easeInOut(duration: 0.25), value: speechService.isRecording)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if horizontalSizeClass == .compact {
                let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
                PersistentSessionStatusBar(
                    pinnedSessions: pinned,
                    onSessionSelected: { selected in onSessionSwitch?(selected) }
                )
            }
        }
    }

    // MARK: - Status Banners

    /// Streaming or connection status indicator shown at the top of the view.
    @ViewBuilder
    var statusBanner: some View {
        if let statusText = viewModel.statusText {
            AsyncOperationBanner(
                message: statusText,
                state: viewModel.connectionState.asAsyncOperationState,
                tokenCount: viewModel.streamTokenCount,
                elapsedSeconds: viewModel.streamElapsedSeconds
            )
            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
        }
    }

    /// In-app compaction alert banner shown when context usage crosses a threshold.
    @ViewBuilder
    var compactionAlertBanner: some View {
        if notifContextCompactionAlerts,
           viewModel.showCompactionAlert,
           let usedTokens = viewModel.contextTokensUsed,
           let windowSize = viewModel.contextWindowSize,
           windowSize > 0 {
            ContextCompactionAlertBanner(
                usedTokens: usedTokens,
                contextWindowSize: windowSize,
                onForkSession: {
                    viewModel.showCompactionAlert = false
                    Task {
                        if let forked = await viewModel.forkSession() {
                            actions.forkedSession = forked
                            sheetDestination = .forkAlert
                        }
                    }
                },
                onSaveSnapshot: {
                    viewModel.showCompactionAlert = false
                    Task { await viewModel.generateContextSnapshot() }
                },
                onDismiss: { viewModel.showCompactionAlert = false },
                onAutoForkSettings: { appState.navigationIntent = .settings }
            )
            .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Compact context window usage bar (shown when enabled in Settings).
    @ViewBuilder
    var contextWindowBar: some View {
        if showContextWindowBar,
           let usedTokens = viewModel.contextTokensUsed,
           let windowSize = viewModel.contextWindowSize,
           windowSize > 0 {
            ContextWindowBar(usedTokens: usedTokens, contextWindowSize: windowSize) {
                sheetDestination = .contextWindowDetail
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Related Sessions Panel

    /// Related past sessions panel shown when the conversation has no messages yet.
    @ViewBuilder
    var relatedSessionsPanel: some View {
        if viewModel.displayMessages.isEmpty && !viewModel.isLoadingHistory {
            RelatedSessionsPanel(
                session: session,
                apiClient: appState.apiClient,
                onNavigate: { related in actions.navigateToRelated = related }
            )
        }
    }

    // MARK: - Message List

    /// Scrollable message history with delete/retry gesture support.
    var messageList: some View {
        ChatMessageList(
            messages: viewModel.displayMessages,
            isStreaming: viewModel.isStreaming,
            isLoadingHistory: viewModel.isLoadingHistory,
            statusText: viewModel.statusText,
            currentStreamingMessage: viewModel.currentStreamingMessage,
            isUserScrolledUp: $isUserScrolledUp,
            showJumpToBottom: $showJumpToBottom,
            onDeleteMessage: { msg in
                actions.messageToDelete = msg
                sheetDestination = .deleteMessageConfirmation
            },
            onRetryMessage: { msg in viewModel.retryMessage(msg, projectId: session.projectId) },
            canLoadMore: viewModel.canLoadOlderMessages,
            isLoadingMore: viewModel.isLoadingOlderMessages,
            onLoadMore: { Task { await viewModel.loadOlderMessages() } },
            sessionProjectId: session.projectId?.uuidString
        )
        .simultaneousGesture(
            sessionSwipeGesture,
            isEnabled: horizontalSizeClass == .compact && onSessionSwitch != nil
        )
        .accessibilityAction(named: "Next Session") {
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            guard pinned.count >= 2,
                  let idx = pinned.firstIndex(where: { $0.id == session.id }) else { return }
            HapticManager.impact(.light)
            onSessionSwitch?(pinned[(idx + 1) % pinned.count])
        }
        .accessibilityAction(named: "Previous Session") {
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            guard pinned.count >= 2,
                  let idx = pinned.firstIndex(where: { $0.id == session.id }) else { return }
            HapticManager.impact(.light)
            onSessionSwitch?(pinned[(idx - 1 + pinned.count) % pinned.count])
        }
        .accessibilityHint({
            let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
            return pinned.count >= 2 ? "Swipe left or right to switch between pinned sessions" : ""
        }())
    }

    // MARK: - Session Swipe Navigation

    /// Horizontal drag gesture for cycling through pinned sessions on iPhone.
    var sessionSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard value.startLocation.x > 50 else { return }
                let translation = value.translation.width
                guard abs(translation) > 60 else { return }
                let pinned = multiSessionVM.pinnedSessions(from: sessionsVM.sessions)
                guard pinned.count >= 2,
                      let currentIndex = pinned.firstIndex(where: { $0.id == session.id }) else { return }
                let target: ChatSession
                if translation < 0 {
                    target = pinned[(currentIndex + 1) % pinned.count]
                } else {
                    target = pinned[(currentIndex - 1 + pinned.count) % pinned.count]
                }
                HapticManager.impact(.light)
                onSessionSwitch?(target)
            }
    }

    // MARK: - Search UI

    var inlineSearchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            TextField("Search messages...", text: $viewModel.searchQuery)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
            Button("Cancel") {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
                viewModel.cancelSearch()
                showSearch = false
            }
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
    }

    @ViewBuilder
    var searchResultsView: some View {
        if viewModel.isSearchLoading {
            VStack { Spacer(); ProgressView().tint(theme.accent); Spacer() }
                .background(theme.bgPrimary)
        } else if viewModel.searchQuery.isEmpty {
            VStack {
                Spacer()
                Text("Type to search messages")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .background(theme.bgPrimary)
        } else if viewModel.searchResults.isEmpty {
            VStack {
                Spacer()
                Text("No results for \"\(viewModel.searchQuery)\"")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)
                Spacer()
            }
            .background(theme.bgPrimary)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { result in
                        MessageSearchResultRow(result: result)
                            .padding(.horizontal, theme.spacingMD)
                        theme.divider.frame(height: 0.5).padding(.leading, theme.spacingMD)
                    }
                }
            }
            .background(theme.bgPrimary)
        }
    }

    // MARK: - Quick Reply Toolbar

    /// Compact horizontal chip bar surfacing pinned and most-used quick reply templates.
    var quickReplyToolbar: some View {
        QuickReplyToolbar(
            templates: quickReplyToolbarTemplates,
            onSelect: { template in
                QuickReplyTemplateManager.shared.recordUsage(
                    id: template.id,
                    projectId: session.projectId?.uuidString
                )
                applyTemplate(template)
            },
            onShowAll: { sheetDestination = .quickReplyTemplates }
        )
    }

    /// Ordered list of templates shown in the quick reply toolbar.
    var quickReplyToolbarTemplates: [QuickReplyTemplate] {
        let manager = QuickReplyTemplateManager.shared
        var seen = Set<UUID>()
        var combined: [QuickReplyTemplate] = []
        for template in manager.pinnedTemplates() + manager.mostUsedTemplates(limit: 5) {
            if seen.insert(template.id).inserted { combined.append(template) }
        }
        return combined
    }

    // MARK: - Bottom Bar

    /// Chat input bar for composing and sending messages.
    var bottomBar: some View {
        VStack(spacing: 0) {
            if viewModel.isOffline && viewModel.queuedMessageCount > 0 {
                offlineQueueIndicator
            }
            chatInputBar.focused($isInputFocused)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: viewModel.isOffline && viewModel.queuedMessageCount > 0
        )
    }

    @ViewBuilder
    var chatInputBar: some View {
        #if os(iOS)
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory || viewModel.isOffline,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { sheetDestination = .commandPalette },
            onAdvancedOptions: { sheetDestination = .advancedOptions },
            onVoiceInput: { toggleVoiceInput() },
            isRecording: speechService.isRecording,
            attachments: $pendingAttachments,
            onAttachmentTap: { sheetDestination = .attachmentPicker },
            session: session,
            apiClient: appState.apiClient,
            onSuggestionTap: { suggestion in
                inputText = suggestion
                isInputFocused = true
            },
            promptSuggestionRefreshToken: promptSuggestionRefreshToken
        )
        #else
        ChatInputBar(
            text: $inputText,
            isStreaming: viewModel.isStreaming,
            isDisabled: viewModel.isLoadingHistory || viewModel.isOffline,
            hasCustomOptions: chatOptionsConfig.hasCustomOptions,
            onSend: sendMessage,
            onCancel: { viewModel.cancel() },
            onCommandPalette: { sheetDestination = .commandPalette },
            onAdvancedOptions: { sheetDestination = .advancedOptions },
            pendingCount: MessageQueueService.shared.pendingCount,
            session: session,
            apiClient: appState.apiClient,
            onSuggestionTap: { suggestion in
                inputText = suggestion
                isInputFocused = true
            },
            promptSuggestionRefreshToken: promptSuggestionRefreshToken
        )
        #endif
    }

    /// Thin strip above the input bar showing how many messages are queued offline.
    @ViewBuilder
    var offlineQueueIndicator: some View {
        let count = viewModel.queuedMessageCount
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: theme.fontCaption, weight: .semibold))
            Text("\(count) message\(count == 1 ? "" : "s") queued — will send when online")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        }
        .foregroundStyle(theme.warning)
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingXS)
        .frame(maxWidth: .infinity)
        .background(
            theme.warning.opacity(0.15)
                .overlay(Rectangle().stroke(theme.warning.opacity(0.3), lineWidth: 0.5))
        )
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel("\(count) message\(count == 1 ? "" : "s") queued. Will send when back online.")
    }
}
