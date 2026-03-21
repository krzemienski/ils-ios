import SwiftUI
import ILSShared

// MARK: - Setup & Lifecycle

extension ChatView {

    /// Configure the view model and load message history.
    func setupChatView() async {
        let draftKey = "chatDraft_\(session.id.uuidString)"
        if let saved = UserDefaults.standard.string(forKey: draftKey), !saved.isEmpty {
            inputText = saved
        }
        viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient)
        viewModel.sessionId = session.id
        viewModel.encodedProjectPath = session.encodedProjectPath
        viewModel.claudeSessionId = session.claudeSessionId
        if session.source == .ils {
            checkpointViewModel.configure(client: appState.apiClient)
            viewModel.checkpointViewModel = checkpointViewModel
            checkpointViewModel.onRestoreCompleted = { [weak viewModel] in
                Task { await viewModel?.refreshMessages() }
            }
        }
        await viewModel.loadMessageHistory()
    }

    // MARK: - onChange Handlers

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { await viewModel.refreshMessages() }
            #if os(iOS)
            SessionMonitorService.shared.removeSession(session.id)
            #endif
        }
        #if os(iOS)
        if newPhase == .background && viewModel.isStreaming {
            SessionMonitorService.shared.addSession(session, apiClient: appState.apiClient)
            SessionMonitorService.shared.scheduleBackgroundTask()
        }
        #endif
    }

    #if os(iOS)
    func handleStreamingStateChange(was wasStreaming: Bool, isNow isNowStreaming: Bool) {
        guard wasStreaming && !isNowStreaming else { return }
        SessionMonitorService.shared.removeSession(session.id)
        let sessionId = session.id
        let sessionName = session.displayName
        if let error = viewModel.error {
            Task {
                await NotificationService.shared.postSessionErrorNotification(
                    sessionId: sessionId,
                    sessionName: sessionName,
                    errorMessage: error.localizedDescription
                )
            }
        } else {
            Task {
                await NotificationService.shared.postStreamingCompleteNotification(
                    sessionId: sessionId,
                    sessionName: sessionName
                )
            }
        }
    }
    #endif

    /// Persist draft text to UserDefaults with a 500ms debounce (DATA-05).
    func persistDraft(_ newValue: String) {
        draftPersistTask?.cancel()
        draftPersistTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let key = "chatDraft_\(session.id.uuidString)"
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }

    /// Debounce search query changes with a 300ms delay.
    func debounceSearch(_ query: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.searchMessages(query: query)
        }
    }

    func handleDisappear() {
        draftPersistTask?.cancel()
        let key = "chatDraft_\(session.id.uuidString)"
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        }
        ChatView.trimDraftKeys()
    }

    // MARK: - Actions

    #if os(iOS)
    /// Toggle voice input recording on or off.
    func toggleVoiceInput() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let granted = await speechService.requestPermissions()
                guard granted else { return }
                try? await speechService.startRecording()
            }
        }
    }
    #endif

    /// Resend the most recent user message after a connection error.
    func retryLastMessage() {
        if let lastUserMessage = viewModel.messages.last(where: { $0.isUser }) {
            viewModel.sendMessage(prompt: lastUserMessage.text, projectId: session.projectId)
        }
    }

    /// Send the current input text as a user message to Claude.
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let prompt = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []
        UserDefaults.standard.removeObject(forKey: "chatDraft_\(session.id.uuidString)")
        draftPersistTask?.cancel()
        viewModel.addUserMessage(prompt, attachments: attachments)
        viewModel.sendMessage(
            prompt: prompt,
            projectId: session.projectId,
            options: chatOptionsConfig.toChatOptions(),
            attachments: attachments
        )
    }

    /// Insert a quick reply template's resolved content into the input field.
    func applyTemplate(_ template: QuickReplyTemplate) {
        let resolved = template.resolvedContent(for: session.projectId?.uuidString)
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = resolved
        } else {
            inputText += " " + resolved
        }
        isInputFocused = true
    }

    /// Pastes the snapshot text into the chat input with a recovery context prefix.
    func pasteSnapshotAsMessage(_ snapshotText: String) {
        let prefix = "The following is a context snapshot captured before this session was compacted. Please use it to restore our working context:\n\n"
        inputText = prefix + snapshotText
        sheetDestination = nil
        viewModel.showPostCompactionRecovery = false
        isInputFocused = true
    }

    /// Dismisses the post-compaction recovery sheet and resets the view model flag.
    func dismissPostCompactionSheet() {
        sheetDestination = nil
        viewModel.showPostCompactionRecovery = false
    }

    // MARK: - Draft Key Maintenance

    /// STOR-002: Caps the number of persisted chat draft keys in UserDefaults to 50.
    static func trimDraftKeys(maxCount: Int = 50) {
        let defaults = UserDefaults.standard
        let prefix = "chatDraft_"
        let draftKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        guard draftKeys.count > maxCount else { return }
        let sorted = draftKeys.sorted()
        let toRemove = sorted.prefix(draftKeys.count - maxCount)
        for key in toRemove { defaults.removeObject(forKey: key) }
    }

    // MARK: - Sheet Context

    /// Builds the full ``ChatSheetContext`` for ``ChatSheetCoordinator``.
    var sheetContext: ChatSheetContext {
        ChatSheetContext(
            session: session,
            chatOptionsConfig: $chatOptionsConfig,
            onCommandSelected: { command in
                inputText = command
                isInputFocused = true
            },
            onTemplateApplied: { template in
                applyTemplate(template)
                sheetDestination = nil
            },
            onAttachmentsAdded: { attachments in
                pendingAttachments.append(contentsOf: attachments)
            },
            contextTokensUsed: viewModel.contextTokensUsed,
            contextWindowSize: viewModel.contextWindowSize,
            contextInputTokens: viewModel.contextInputTokens,
            contextOutputTokens: viewModel.contextOutputTokens,
            contextCacheReadTokens: viewModel.contextCacheReadTokens,
            contextCacheCreateTokens: viewModel.contextCacheCreateTokens,
            onForkFromContextDetail: {
                Task { await viewModel.performFork() }
            },
            onPermissionDecision: { requestId, decision in
                viewModel.respondToPermission(requestId: requestId, decision: decision)
                sheetDestination = nil
            },
            pendingPermissionRequests: viewModel.pendingPermissionRequests,
            showBatchPermissionModal: Binding(
                get: { viewModel.showBatchPermissionModal },
                set: { viewModel.showBatchPermissionModal = $0 }
            ),
            onBatchPermissionDecision: { requestIds, decision in
                viewModel.respondToBatchPermissions(requestIds: requestIds, decision: decision)
                sheetDestination = nil
            },
            compactionTokensBefore: viewModel.compactionTokensBefore ?? 0,
            compactionTokensAfter: viewModel.contextTokensUsed ?? 0,
            compactionSnapshot: viewModel.compactionSnapshot,
            onPasteSnapshot: pasteSnapshotAsMessage,
            onDismissCompaction: dismissPostCompactionSheet,
            errorMessage: viewModel.error?.localizedDescription ?? "",
            onRetryLastMessage: retryLastMessage,
            forkedSession: actions.forkedSession,
            onOpenFork: { actions.navigateToForked = actions.forkedSession },
            onConfirmDeleteMessage: {
                if let msg = actions.messageToDelete {
                    viewModel.deleteMessage(msg)
                    actions.messageToDelete = nil
                }
            },
            renameText: $actions.renameText,
            onConfirmRename: {
                Task { await viewModel.renameSession(name: actions.renameText) }
            },
            onConfirmDeleteSession: {
                await viewModel.deleteSession()
            }
        )
    }
}
