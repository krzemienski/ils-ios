import Foundation
import Observation
import ILSShared

/// View model for chat interactions with Claude Code.
///
/// Manages chat message history, SSE streaming connections, and real-time message updates.
/// Coordinates with `SSEClient` for Server-Sent Events and `APIClient` for REST operations.
///
/// ## Topics
/// ### Properties
/// - ``messages`` - Array of chat messages in the conversation
/// - ``isStreaming`` - Whether Claude is currently responding
/// - ``isLoadingHistory`` - Whether message history is being loaded
/// - ``connectionState`` - Current SSE connection state
/// - ``pendingPermissionRequest`` - Permission request awaiting user decision
///
/// ### Message Operations
/// - ``sendMessage(_:projectId:claudeSessionId:)`` - Send a message to Claude
/// - ``loadMessageHistory()`` - Load message history for the session
/// - ``cancelStream()`` - Cancel the active streaming response
@Observable
@MainActor
class ChatViewModel {
    /// Array of messages in the conversation.
    var messages: [ChatMessage] = []
    /// Whether Claude is currently streaming a response.
    var isStreaming = false
    /// Whether message history is being loaded.
    var isLoadingHistory = false
    /// Current error, if any.
    var error: Error?
    /// Current SSE connection state.
    var connectionState: SSEClient.ConnectionState = .disconnected
    /// Whether connection is taking longer than expected (>3s).
    var connectingTooLong = false
    /// Number of tokens in the current stream.
    var streamTokenCount: Int = 0
    /// Elapsed time in seconds for the current stream.
    var streamElapsedSeconds: Double = 0
    /// Pending permission request from Claude.
    var pendingPermissionRequest: PermissionRequest?
    /// Start time of the current stream, used for elapsed time calculations.
    /// Internal access for Live Activity extension.
    var streamStartTime: Date?

    // MARK: - Offline Message Queue

    /// Whether the backend server is currently reachable.
    /// Set externally by the hosting view to reflect `appState.isConnected`.
    var isConnected: Bool = true

    /// True when there are messages queued for this session awaiting delivery.
    var hasPendingQueuedMessages: Bool {
        guard sessionId != nil else { return false }
        return MessageQueueService.shared.pendingCount > 0
    }

    // MARK: - Search State
    /// Whether in-session message search is active.
    var isSearchActive = false
    /// Current search query text.
    var searchQuery: String = ""
    /// Search results from the backend.
    var searchResults: [MessageSearchResult] = []
    /// Whether a search request is in flight.
    var isSearchLoading = false

    // MARK: - Context Window Properties

    /// Total context window size in tokens for the current model (nil until first result).
    var contextWindowSize: Int? = nil
    /// Total tokens used in the current context (input + output, nil until first result).
    var contextTokensUsed: Int? = nil
    /// Input tokens for the latest result (includes cache reads).
    var contextInputTokens: Int = 0
    /// Output tokens for the latest result.
    var contextOutputTokens: Int = 0
    /// Cache read tokens for the latest result.
    var contextCacheReadTokens: Int = 0
    /// Cache creation tokens for the latest result.
    var contextCacheCreateTokens: Int = 0

    // MARK: - Compaction Alert Properties

    /// The highest context usage threshold (85/90/95%) that has been crossed, triggering the alert.
    var compactionAlertThreshold: Double? = nil
    /// Whether to show the compaction alert banner.
    var showCompactionAlert: Bool = false
    /// Thresholds already alerted this session — prevents re-alerting at the same level.
    private var alertedThresholds: Set<Int> = []

    /// Whether to show the post-compaction recovery banner.
    /// Set to `true` when a > 20% drop in contextTokensUsed is detected between turns,
    /// indicating Claude Code performed an automatic context compaction.
    var showPostCompactionRecovery: Bool = false
    /// Text of the most recently saved context snapshot, surfaced as a recovery suggestion
    /// after a compaction event is detected.
    var lastSnapshotText: String? = nil
    /// Token count recorded immediately before the most recent compaction event was detected.
    var compactionTokensBefore: Int? = nil
    /// Most recent context snapshot loaded after a compaction event is detected.
    var compactionSnapshot: ContextSnapshot? = nil

    /// Context window usage as a percentage (0–100), or nil if data not yet available.
    var contextUsagePercent: Double? {
        guard let used = contextTokensUsed, let total = contextWindowSize, total > 0 else { return nil }
        return Double(used) / Double(total) * 100.0
    }

    /// Computed property for current assistant message being streamed
    var currentStreamingMessage: ChatMessage? {
        guard isStreaming, let lastMessage = messages.last, !lastMessage.isUser else {
            return nil
        }
        return lastMessage
    }

    /// Human-readable status text for connection state
    var statusText: String? {
        if isLoadingHistory {
            return "Loading history..."
        }
        switch connectionState {
        case .disconnected:
            return nil
        case .connecting:
            return connectingTooLong ? "Taking longer than expected..." : "Connecting..."
        case .connected:
            return isStreaming ? "Claude is responding..." : nil
        case .reconnecting(let attempt):
            return "Reconnecting (attempt \(attempt)/3)..."
        }
    }

    var sessionId: UUID?
    /// For external sessions: the encoded project path (e.g. "-Users-nick-Desktop-project")
    var encodedProjectPath: String?
    /// For external sessions: the claude session ID string
    var claudeSessionId: String?

    /// Display name for the session, used by Live Activity.
    var sessionDisplayName: String?
    /// Model name for the session, used by Live Activity.
    var sessionModel: String?

    private var sseClient: SSEClient?
    private var apiClient: APIClient?
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var connectingTimer: Task<Void, Never>?

    // MARK: - Shared Decoder
    // nonisolated: JSONDecoder is thread-safe for decoding. Isolated to instance lifetime.
    nonisolated private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Message Windowing
    private let messageWindowSize = 50
    private(set) var totalMessageCount = 0
    private var currentOffset = 0
    var canLoadOlderMessages: Bool { currentOffset > 0 }
    var isLoadingOlderMessages = false

    // MARK: - Display Windowing

    /// Windowed messages for display -- shows the most recent messages up to displayWindowSize.
    /// For small conversations, returns all messages.
    var displayMessages: [ChatMessage] {
        let windowSize = messageWindowSize
        if messages.count <= windowSize {
            return messages
        }
        return Array(messages.suffix(windowSize))
    }

    /// Whether older messages exist beyond the current display window.
    var hasOlderDisplayMessages: Bool {
        messages.count > messageWindowSize
    }

    // MARK: - Batching Properties
    private var pendingStreamMessages: [StreamMessage] = []
    @ObservationIgnored private var batchTask: Task<Void, Never>?
    private let batchInterval: TimeInterval = 0.075
    private var lastProcessedMessageIndex = 0

    init() {}

    func configure(client: APIClient, sseClient: SSEClient) {
        self.apiClient = client
        self.sseClient = sseClient
        setupBindings()
    }

    deinit {
        batchTask?.cancel()
        connectingTimer?.cancel()
        for task in observationTasks { task.cancel() }
    }

    private func setupBindings() {
        guard let sseClient else { return }

        // Cancel any previous observation tasks
        for task in observationTasks { task.cancel() }
        observationTasks.removeAll()

        // Observe network restoration to drain the offline message queue
        observationTasks.append(Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .networkDidBecomeAvailable) {
                guard !Task.isCancelled else { break }
                self?.drainQueue()
            }
        })

        // Single observation task that tracks all SSEClient properties
        // Uses withObservationTracking (Swift Observation) instead of Combine publishers
        observationTasks.append(Task { @MainActor [weak self] in
            var lastStreaming = sseClient.isStreaming
            var lastState = sseClient.connectionState
            var lastMessageCount = 0

            while let self, !Task.isCancelled {
                // Wait for any tracked SSEClient property to change
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = sseClient.isStreaming
                        _ = sseClient.error
                        _ = sseClient.connectionState
                        _ = sseClient.messages
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { break }

                // Sync isStreaming
                let streaming = sseClient.isStreaming
                if streaming != lastStreaming {
                    self.isStreaming = streaming
                    if streaming {
                        self.streamTokenCount = 0
                        self.streamElapsedSeconds = 0
                        self.streamStartTime = Date()
                        lastMessageCount = 0
                        // Start Live Activity for Dynamic Island
                        #if os(iOS)
                        if #available(iOS 16.2, *) {
                            let sessionName = self.sessionDisplayName ?? "Chat Session"
                            let model = self.sessionModel ?? "claude"
                            self.startLiveActivity(sessionName: sessionName, model: model)
                        }
                        #endif
                    } else {
                        self.flushPendingMessages()
                        self.stopBatchTimer()
                        // Preserve current message count to prevent re-processing
                        // all messages on the next observation cycle (was resetting
                        // to 0, causing full replay and text duplication).
                        let finalCount = sseClient.messages.count
                        self.lastProcessedMessageIndex = finalCount
                        // End Live Activity
                        #if os(iOS)
                        if #available(iOS 16.2, *) {
                            self.endLiveActivity()
                        }
                        #endif
                        self.streamStartTime = nil
                        lastMessageCount = finalCount
                    }
                    lastStreaming = streaming
                }

                // Sync error
                self.error = sseClient.error

                // Sync connectionState
                let state = sseClient.connectionState
                if state != lastState {
                    self.connectionState = state
                    if case .connecting = state {
                        self.startConnectingTimer()
                    } else {
                        self.connectingTimer?.cancel()
                        self.connectingTimer = nil
                        self.connectingTooLong = false
                    }
                    lastState = state
                }

                // Process new messages
                let msgs = sseClient.messages
                if msgs.count > lastMessageCount {
                    let newMessages = msgs.suffix(from: self.lastProcessedMessageIndex)
                    if !newMessages.isEmpty {
                        self.pendingStreamMessages.reserveCapacity(self.pendingStreamMessages.count + newMessages.count)
                        self.pendingStreamMessages.append(contentsOf: newMessages)
                        self.lastProcessedMessageIndex = msgs.count
                        self.startBatchTimer()
                        // Update Live Activity with latest message preview
                        #if os(iOS)
                        if #available(iOS 16.2, *) {
                            let preview: String
                            if let lastMsg = self.messages.last, !lastMsg.isUser {
                                preview = String(lastMsg.text.prefix(100))
                            } else {
                                preview = ""
                            }
                            self.updateLiveActivity(
                                preview: preview,
                                tokens: self.streamTokenCount,
                                cost: 0.0
                            )
                        }
                        #endif
                    }
                    lastMessageCount = msgs.count
                }
            }
        })
    }

    /// Start the batch timer to flush pending messages at regular intervals
    private func startBatchTimer() {
        guard batchTask == nil else { return }

        batchTask = Task { [weak self] in
            let intervalNanos = UInt64((self?.batchInterval ?? 0.075) * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                guard !Task.isCancelled else { break }
                self?.flushPendingMessages()
            }
        }
    }

    /// Stop the batch timer
    private func stopBatchTimer() {
        batchTask?.cancel()
        batchTask = nil
    }

    private func startConnectingTimer() {
        connectingTimer?.cancel()
        connectingTooLong = false
        connectingTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.connectingTooLong = true
        }
    }

    /// Flush pending messages to UI immediately
    private func flushPendingMessages() {
        guard !pendingStreamMessages.isEmpty else { return }

        let messagesToProcess = pendingStreamMessages
        pendingStreamMessages.removeAll()

        processStreamMessages(messagesToProcess)
    }

    /// Load message history for the current session from the backend
    func loadMessageHistory() async {
        guard let apiClient else { return }

        isLoadingHistory = true
        error = nil

        do {
            // Branch: external sessions load from JSONL transcript, ILS sessions from DB
            if let encodedProjectPath = encodedProjectPath, let claudeSessionId = claudeSessionId {
                // First, fetch with limit to get total count
                let initialPath = "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)?limit=\(messageWindowSize)"
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get(initialPath)

                if let data = response.data {
                    totalMessageCount = data.total

                    // If more messages exist than the window, fetch the last window
                    let finalItems: [Message]
                    if totalMessageCount > messageWindowSize {
                        currentOffset = max(0, totalMessageCount - messageWindowSize)
                        let windowPath = "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)?limit=\(messageWindowSize)&offset=\(currentOffset)"
                        let windowResponse: APIResponse<ListResponse<Message>> = try await apiClient.get(windowPath)
                        finalItems = windowResponse.data?.items ?? data.items
                    } else {
                        currentOffset = 0
                        finalItems = data.items
                    }

                    let loadedMessages = finalItems.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }
                    messages = loadedMessages

                    // Cache messages for offline access (DATA-03)
                    if let sessionId = sessionId {
                        let messagesToCache = finalItems
                        Task { await CacheService.shared.cacheMessages(messagesToCache, forSession: sessionId) }
                    }

                    if messages.isEmpty {
                        showEmptyTranscriptMessage()
                    }
                }
            } else if let sessionId = sessionId {
                // First, fetch with limit to get total count
                let initialPath = "/sessions/\(sessionId.uuidString)/messages?limit=\(messageWindowSize)"
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get(initialPath)

                if let data = response.data {
                    totalMessageCount = data.total

                    // If more messages exist than the window, fetch the last window
                    let finalItems: [Message]
                    if totalMessageCount > messageWindowSize {
                        currentOffset = max(0, totalMessageCount - messageWindowSize)
                        let windowPath = "/sessions/\(sessionId.uuidString)/messages?limit=\(messageWindowSize)&offset=\(currentOffset)"
                        let windowResponse: APIResponse<ListResponse<Message>> = try await apiClient.get(windowPath)
                        finalItems = windowResponse.data?.items ?? data.items
                    } else {
                        currentOffset = 0
                        finalItems = data.items
                    }

                    let loadedMessages = finalItems.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            toolResults: parseToolResults(from: message.toolResults),
                            thinking: nil,
                            cost: nil,
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }

                    messages = loadedMessages

                    // Cache messages for offline access (DATA-03)
                    let messagesToCache = finalItems
                    Task { await CacheService.shared.cacheMessages(messagesToCache, forSession: sessionId) }

                    if messages.isEmpty {
                        showWelcomeMessage()
                    }
                }
            }
        } catch {
            // For new sessions, a 404 just means no messages yet — show welcome, not error
            let isNotFound = (error as? APIError)?.isNotFound == true
            if !isNotFound {
                self.error = error
            }
            AppLogger.shared.error("Failed to load message history: \(error)", category: "chat")

            // Offline fallback: load cached messages (DATA-03)
            if let sessionId = sessionId {
                let cached = await CacheService.shared.getCachedMessages(forSession: sessionId)
                if !cached.isEmpty {
                    messages = cached.map { message in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }
                    AppLogger.shared.info("Loaded \(cached.count) cached messages for session \(sessionId)", category: "chat")
                }
            }

            if messages.isEmpty {
                if encodedProjectPath != nil {
                    showEmptyTranscriptMessage()
                } else {
                    showWelcomeMessage()
                }
            }
        }

        isLoadingHistory = false
    }

    /// Load older messages from before the current window and prepend them.
    func loadOlderMessages() async {
        guard canLoadOlderMessages, !isLoadingOlderMessages, let apiClient else { return }
        isLoadingOlderMessages = true

        let newOffset = max(0, currentOffset - messageWindowSize)
        let fetchLimit = currentOffset - newOffset
        guard fetchLimit > 0 else {
            isLoadingOlderMessages = false
            return
        }

        do {
            if let encodedProjectPath, let claudeSessionId {
                let path = "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)?limit=\(fetchLimit)&offset=\(newOffset)"
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get(path)
                if let data = response.data {
                    let olderMessages = data.items.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }
                    messages = olderMessages + messages
                }
            } else if let sessionId {
                let path = "/sessions/\(sessionId.uuidString)/messages?limit=\(fetchLimit)&offset=\(newOffset)"
                let response: APIResponse<ListResponse<Message>> = try await apiClient.get(path)
                if let data = response.data {
                    let olderMessages = data.items.map { message -> ChatMessage in
                        ChatMessage(
                            id: message.id,
                            isUser: message.role == .user,
                            text: message.content,
                            toolCalls: parseToolCalls(from: message.toolCalls),
                            toolResults: parseToolResults(from: message.toolResults),
                            thinking: nil,
                            cost: nil,
                            timestamp: message.createdAt,
                            isFromHistory: true
                        )
                    }
                    messages = olderMessages + messages
                }
            }
            currentOffset = newOffset
        } catch {
            AppLogger.shared.error("Failed to load older messages: \(error)", category: "chat")
        }

        isLoadingOlderMessages = false
    }

    /// Reload messages on foreground return, preserving any in-progress stream
    func refreshMessages() async {
        guard !isStreaming else { return } // Don't interrupt active streams
        await loadMessageHistory()
    }

    /// Display a welcome message for new/empty sessions
    private func showWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            isUser: false,
            text: "Hello! I'm Claude, your AI assistant. How can I help you today?",
            isFromHistory: true
        )
        messages = [welcomeMessage]
    }

    /// Display message when transcript has no readable messages
    private func showEmptyTranscriptMessage() {
        let emptyMessage = ChatMessage(
            isUser: false,
            text: "This session transcript contains no readable messages.",
            isFromHistory: true
        )
        messages = [emptyMessage]
    }

    /// Parse tool calls JSON string into ToolCallDisplay array
    private func parseToolCalls(from jsonString: String?) -> [ToolCallDisplay] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let blocks = try jsonDecoder.decode([ToolUseBlock].self, from: data)
            return blocks.map { block in
                ToolCallDisplay(id: block.id, name: block.name, inputPreview: nil)
            }
        } catch {
            AppLogger.shared.error("Failed to parse tool calls: \(error)", category: "chat")
            return []
        }
    }

    /// Parse tool results JSON string into ToolResultDisplay array
    private func parseToolResults(from jsonString: String?) -> [ToolResultDisplay] {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let blocks = try jsonDecoder.decode([ToolResultBlock].self, from: data)
            return blocks.map { block in
                ToolResultDisplay(toolUseId: block.toolUseId, content: block.content, isError: block.isError)
            }
        } catch {
            AppLogger.shared.error("Failed to parse tool results: \(error)", category: "chat")
            return []
        }
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(isUser: true, text: text))
    }

    /// Send a message, or enqueue it for later delivery if the server is unreachable.
    func sendMessage(prompt: String, projectId: UUID?, options: ChatOptions? = nil) {
        guard isConnected else {
            if let sessionId {
                let queued = QueuedMessage(sessionId: sessionId, content: prompt)
                MessageQueueService.shared.enqueue(queued)
                AppLogger.shared.info("Message queued while offline: \(prompt.prefix(50))", category: "chat")
            }
            return
        }
        performSend(prompt: prompt, projectId: projectId, options: options)
    }

    /// Deliver all messages queued for the current session now that connectivity is restored.
    /// Messages are sent one at a time: each send waits for the prior stream to finish
    /// before starting the next, preventing `sseClient.startStream()` from cancelling
    /// in-flight streams (which would silently lose all but the last queued message).
    func drainQueue() {
        guard isConnected, let sessionId else { return }

        let all = MessageQueueService.shared.dequeueAll()
        guard !all.isEmpty else { return }

        // Separate messages for this session from other sessions
        let mine = all.filter { $0.sessionId == sessionId }
        let others = all.filter { $0.sessionId != sessionId }

        // Re-enqueue messages belonging to other sessions
        for msg in others {
            MessageQueueService.shared.enqueue(msg)
        }

        guard !mine.isEmpty else { return }
        AppLogger.shared.info("Draining \(mine.count) queued message(s) for session \(sessionId)", category: "chat")

        // Send sequentially: wait for each stream to complete before starting the next.
        Task { @MainActor [weak self] in
            for queued in mine {
                guard let self, self.isConnected else { break }

                // Wait for any in-flight stream to finish before sending the next message.
                // Uses withObservationTracking to avoid spinning — fires exactly once
                // per isStreaming change, then re-registers until streaming is false.
                while self.isStreaming {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self.isStreaming
                        } onChange: {
                            continuation.resume()
                        }
                    }
                }

                guard self.isConnected else { break }
                self.performSend(prompt: queued.content, projectId: nil, options: nil)
            }
        }
    }

    /// Core send implementation — builds and starts the SSE stream request.
    private func performSend(prompt: String, projectId: UUID?, options: ChatOptions? = nil) {
        guard let sseClient else { return }

        // For external sessions, inject claudeSessionId as resume option
        var finalOptions = options
        if let claudeId = claudeSessionId {
            finalOptions = ChatOptions(
                model: options?.model,
                permissionMode: options?.permissionMode,
                maxTurns: options?.maxTurns,
                maxBudgetUSD: options?.maxBudgetUSD,
                allowedTools: options?.allowedTools,
                disallowedTools: options?.disallowedTools,
                resume: claudeId,
                forkSession: options?.forkSession,
                systemPrompt: options?.systemPrompt,
                appendSystemPrompt: options?.appendSystemPrompt,
                addDirs: options?.addDirs,
                continueConversation: options?.continueConversation,
                includePartialMessages: options?.includePartialMessages,
                noSessionPersistence: options?.noSessionPersistence,
                inputFormat: options?.inputFormat,
                agent: options?.agent,
                betas: options?.betas,
                debug: options?.debug,
                backend: options?.backend
            )
        }

        let request = ChatStreamRequest(
            prompt: prompt,
            sessionId: sessionId,
            projectId: projectId,
            options: finalOptions
        )

        sseClient.startStream(request: request)
    }

    /// Retry by removing the assistant response and resending the preceding user message
    func retryMessage(_ message: ChatMessage, projectId: UUID?) {
        guard !message.isUser else { return }
        // Find the index of this assistant message
        guard let assistantIndex = messages.firstIndex(where: { $0.id == message.id }) else { return }
        // Find the preceding user message
        let precedingUserMessage = messages[..<assistantIndex].last(where: { $0.isUser })
        // Remove the assistant message (SPERF-HIGH: remove(at:) instead of filter)
        messages.remove(at: assistantIndex)
        // Resend if we found a user message
        if let userMessage = precedingUserMessage {
            sendMessage(prompt: userMessage.text, projectId: projectId)
        }
    }

    /// Delete a message from the local messages array
    func deleteMessage(_ message: ChatMessage) {
        // SPERF-HIGH: remove(at:) instead of O(n) filter rebuild
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }
    }

    func cancel() {
        // Notify backend to kill Claude CLI process (best-effort, fire-and-forget)
        if let sessionId = sessionId, let apiClient = apiClient {
            Task { [weak self] in
                _ = self  // prevent unused capture warning
                do {
                    let _: APIResponse<DeletedResponse> = try await apiClient.post("/chat/cancel/\(sessionId.uuidString)", body: EmptyBody())
                } catch {
                    // Cancel is best-effort — don't surface errors to user
                    AppLogger.shared.warning("Backend cancel failed (non-fatal): \(error)", category: "chat")
                }
            }
        }
        sseClient?.cancel()
    }

    /// Respond to a pending permission request (allow/deny)
    ///
    /// Sends the decision to the backend which forwards it to the Claude CLI process via stdin.
    /// Route: POST /chat/permission/{sessionId}/{requestId}
    func respondToPermission(requestId: String, decision: String) {
        guard let apiClient, let sessionId else { return }
        pendingPermissionRequest = nil

        Task { [weak self] in
            _ = self  // prevent unused capture warning
            do {
                let body = PermissionDecision(decision: decision)
                let _: APIResponse<AcknowledgedResponse> = try await apiClient.post(
                    "/chat/permission/\(sessionId.uuidString)/\(requestId)",
                    body: body
                )
            } catch {
                AppLogger.shared.warning("Permission response failed (non-fatal): \(error)", category: "chat")
            }
        }
    }

    /// Rename the current session.
    func renameSession(name: String) async {
        guard let sessionId = sessionId, let apiClient else { return }

        do {
            let _: APIResponse<ChatSession> = try await apiClient.renameSession(id: sessionId, name: name)
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to rename session: \(error)", category: "chat")
        }
    }

    /// Delete the current session permanently.
    /// Returns `true` if the deletion succeeded.
    func deleteSession() async -> Bool {
        guard let sessionId = sessionId, let apiClient else { return false }

        do {
            let _: APIResponse<String> = try await apiClient.delete("/sessions/\(sessionId.uuidString)")
            return true
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete session: \(error)", category: "chat")
            return false
        }
    }

    /// Fork the current session
    func forkSession() async -> ChatSession? {
        guard let sessionId = sessionId, let apiClient else { return nil }

        do {
            let response: APIResponse<ChatSession> = try await apiClient.post("/sessions/\(sessionId.uuidString)/fork", body: EmptyBody())
            if response.data != nil {
                messages.append(ChatMessage.systemEvent("Session forked", eventType: .sessionForked))
            }
            return response.data
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to fork session: \(error)", category: "chat")
            return nil
        }
    }

    // MARK: - Search

    /// Search messages in the current session matching the given query.
    ///
    /// Calls `GET /sessions/:id/messages/search?q=` and populates ``searchResults``.
    /// Does nothing if no session ID is set or the query is empty.
    func searchMessages(query: String) async {
        guard let apiClient, let sessionId else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearchLoading = true

        do {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let path = "/sessions/\(sessionId.uuidString)/messages/search?q=\(encoded)"
            let response: APIResponse<ListResponse<MessageSearchResult>> = try await apiClient.get(path)
            searchResults = response.data?.items ?? []
        } catch {
            AppLogger.shared.error("Failed to search messages: \(error.localizedDescription)", category: "chat")
            searchResults = []
        }

        isSearchLoading = false
    }

    /// Cancel the current search and reset all search state.
    func cancelSearch() {
        isSearchActive = false
        searchQuery = ""
        searchResults = []
        isSearchLoading = false
    }

    // MARK: - Compaction Threshold Monitoring

    /// Check context usage percent against 85%/90%/95% thresholds and trigger alerts for any
    /// newly-crossed levels. Each threshold alerts at most once per session. The banner is shown
    /// at the highest newly-crossed threshold.
    ///
    /// When 85% is newly crossed and `autoSnapshotEnabled` is set in UserDefaults, an
    /// automatic context snapshot is saved via ``generateContextSnapshot()``.
    private func checkCompactionThresholds() {
        guard let percent = contextUsagePercent else { return }

        let thresholds = [85, 90, 95]
        var highestNewThreshold: Int? = nil
        var shouldAutoSnapshot = false

        for threshold in thresholds {
            if percent >= Double(threshold), !alertedThresholds.contains(threshold) {
                alertedThresholds.insert(threshold)
                highestNewThreshold = threshold
                if threshold == 85 {
                    shouldAutoSnapshot = true
                }
            }
        }

        if let threshold = highestNewThreshold {
            compactionAlertThreshold = Double(threshold)
            showCompactionAlert = true
        }

        if shouldAutoSnapshot && UserDefaults.standard.bool(forKey: "autoSnapshotEnabled") {
            Task { [weak self] in await self?.generateContextSnapshot() }
        }
    }

    /// Detect a significant drop in context token usage between turns, which indicates
    /// Claude Code performed an automatic context compaction. A drop > 20% relative to
    /// the previous value triggers post-compaction recovery mode.
    ///
    /// When compaction is detected, ``showPostCompactionRecovery`` is set to `true` and
    /// the most recent snapshot for the session is loaded into ``lastSnapshotText`` so
    /// the UI can surface it as a recovery suggestion.
    private func checkPostCompactionDrop(previous: Int, new: Int) {
        guard previous > 0 else { return }
        let dropFraction = Double(previous - new) / Double(previous)
        guard dropFraction > 0.20 else { return }

        showPostCompactionRecovery = true
        compactionTokensBefore = previous
        AppLogger.shared.info("Post-compaction drop detected: \(previous) → \(new) tokens (\(String(format: "%.0f", dropFraction * 100))% drop)", category: "sessionMemory")

        // Load the most recent snapshot to surface as a recovery suggestion
        guard let sessionId else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let snapshots = try await SessionMemoryService.shared.fetchSnapshots(forSession: sessionId)
                if let latest = snapshots.first {
                    self.lastSnapshotText = latest.snapshotText
                    self.compactionSnapshot = latest
                }
            } catch {
                AppLogger.shared.error("Failed to load snapshot for post-compaction recovery: \(error)", category: "sessionMemory")
            }
        }
    }

    // MARK: - Snapshot Generation

    /// Generate and persist a context snapshot summarising the current conversation state.
    ///
    /// Creates a plain-text summary of up to 15 recent messages, prioritising user turns
    /// and key tool results. The snapshot is stored via ``SessionMemoryService`` so it
    /// survives context compaction events and can be reviewed post-compaction.
    ///
    /// - Returns: `true` if the snapshot was saved successfully, `false` otherwise.
    @discardableResult
    func generateContextSnapshot() async -> Bool {
        guard let sessionId,
              let usedTokens = contextTokensUsed,
              let windowSize = contextWindowSize else { return false }

        let snapshotText = buildSnapshotText()
        guard !snapshotText.isEmpty else { return false }

        do {
            try await SessionMemoryService.shared.saveSnapshot(
                sessionId: sessionId,
                usedTokens: usedTokens,
                windowSize: windowSize,
                snapshotText: snapshotText
            )
            // Cache locally so post-compaction recovery can surface it without an extra DB read
            lastSnapshotText = snapshotText
            AppLogger.shared.info("Context snapshot saved for session \(sessionId)", category: "sessionMemory")
            return true
        } catch {
            AppLogger.shared.error("Failed to save context snapshot: \(error)", category: "sessionMemory")
            return false
        }
    }

    /// Build a plain-text summary of recent conversation context.
    ///
    /// Takes the most recent 15 messages (skipping system events), prioritising user turns.
    /// Long assistant messages are truncated to 500 characters. Tool call names and a brief
    /// preview of tool results are included to capture key activity.
    private func buildSnapshotText() -> String {
        let snapshotWindowSize = 15
        let recentMessages = messages.suffix(snapshotWindowSize)
        guard !recentMessages.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("Context Snapshot — \(Date().formatted())")
        if let used = contextTokensUsed, let total = contextWindowSize {
            let pct = String(format: "%.0f", contextUsagePercent ?? 0)
            lines.append("Usage: \(used)/\(total) tokens (\(pct)%)")
        }
        lines.append("")

        for message in recentMessages {
            // Skip injected system event messages (e.g. "Session started")
            if message.isSystem { continue }

            let role = message.isUser ? "User" : "Assistant"
            var text = message.text

            // Truncate long assistant messages to keep the snapshot concise
            if !message.isUser && text.count > 500 {
                text = String(text.prefix(500)) + "…"
            }

            if !text.isEmpty {
                lines.append("[\(role)] \(text)")
            }

            // Summarise tool calls by name
            if !message.toolCalls.isEmpty {
                let toolNames = message.toolCalls.map { $0.name }.joined(separator: ", ")
                lines.append("  Tools: \(toolNames)")
            }

            // Include brief tool result previews; highlight errors
            for result in message.toolResults {
                if result.isError {
                    let preview = String(result.content.prefix(200))
                    lines.append("  Tool result (error): \(preview)")
                } else if !result.content.isEmpty {
                    let preview = String(result.content.prefix(150))
                    lines.append("  Tool result: \(preview)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func processStreamMessages(_ streamMessages: [StreamMessage]) {
        // Find or create current assistant message.
        // Guard against re-popping injected system event messages (isSystem: true).
        var currentMessage: ChatMessage
        if let lastMessage = messages.last, !lastMessage.isUser, !lastMessage.isFromHistory, !lastMessage.isSystem {
            currentMessage = lastMessage
            messages.removeLast()
        } else {
            currentMessage = ChatMessage(isUser: false, text: "")
            // Pre-allocate for streaming responses to reduce reallocations
            currentMessage.text.reserveCapacity(8192)
        }

        for streamMessage in streamMessages {
            switch streamMessage {
            case .system(let sysMsg):
                AppLogger.shared.info("Session initialized: \(sysMsg.data.sessionId)", category: "chat")
                if sysMsg.subtype == "init" {
                    // Flush any in-progress assistant content before the system event.
                    if !currentMessage.text.isEmpty || !currentMessage.toolCalls.isEmpty {
                        messages.append(currentMessage)
                        currentMessage = ChatMessage(isUser: false, text: "")
                        currentMessage.text.reserveCapacity(8192)
                    }
                    messages.append(ChatMessage.systemEvent("Session started", eventType: .sessionStarted))
                    // Reset compaction alert state for the new session.
                    alertedThresholds.removeAll()
                    showCompactionAlert = false
                    compactionAlertThreshold = nil
                    showPostCompactionRecovery = false
                    lastSnapshotText = nil
                    compactionTokensBefore = nil
                    compactionSnapshot = nil
                }

            case .assistant(let assistantMsg):
                handleAssistantMessage(assistantMsg, message: &currentMessage)

            case .result(let resultMsg):
                currentMessage.cost = resultMsg.totalCostUSD

                // Extract context window data from result message
                if let usage = resultMsg.usage {
                    let inputTokens = usage.inputTokens
                    let outputTokens = usage.outputTokens
                    let cacheRead = usage.cacheReadInputTokens ?? 0
                    let cacheCreate = usage.cacheCreationInputTokens ?? 0

                    let newTokensUsed = inputTokens + outputTokens
                    let previousTokens = contextTokensUsed

                    contextInputTokens = inputTokens
                    contextOutputTokens = outputTokens
                    contextCacheReadTokens = cacheRead
                    contextCacheCreateTokens = cacheCreate
                    contextTokensUsed = newTokensUsed

                    // Detect post-compaction token drop (> 20% reduction between turns)
                    if let prev = previousTokens {
                        checkPostCompactionDrop(previous: prev, new: newTokensUsed)
                    }

                    // Real per-message output token count
                    currentMessage.tokenCount = outputTokens
                }

                // Extract context window size from per-model usage
                if let windowSize = resultMsg.modelUsage?.values.first?.contextWindow {
                    contextWindowSize = windowSize
                }

                // Check if usage has crossed a compaction alert threshold.
                checkCompactionThresholds()

            case .permission(let permissionReq):
                pendingPermissionRequest = permissionReq

            case .user(let userMsg):
                handleUserMessage(userMsg, message: &currentMessage)

            case .streamEvent(let event):
                handleStreamEvent(event, message: &currentMessage)

            case .error(let errorMsg):
                currentMessage.text += "\n\nError: \(errorMsg.message)"
            }
        }

        // Update streaming stats
        if let startTime = streamStartTime {
            streamElapsedSeconds = Date().timeIntervalSince(startTime)
        }
        // Approximate token count from text length (rough: ~4 chars per token)
        streamTokenCount = max(streamTokenCount, currentMessage.text.count / 4)

        // Only append the assistant message if it carries content. A system-only
        // batch (e.g. just a session-init event) leaves currentMessage empty.
        if !currentMessage.text.isEmpty || !currentMessage.toolCalls.isEmpty {
            messages.append(currentMessage)
        }
    }

    // MARK: - Stream Message Handlers

    /// Handle assistant message: accumulate text, tool calls, tool results, and thinking blocks.
    /// The assistant event contains the authoritative final content for each block.
    /// Use assignment (not append) for text to avoid duplication with prior streaming deltas.
    private func handleAssistantMessage(_ assistantMsg: AssistantMessage, message: inout ChatMessage) {
        for block in assistantMsg.content {
            switch block {
            case .text(let textBlock):
                message.text = textBlock.text

            case .toolUse(let toolUseBlock):
                message.toolCalls.append(ToolCallDisplay(
                    id: toolUseBlock.id,
                    name: toolUseBlock.name,
                    inputPreview: nil
                ))

            case .toolResult(let resultBlock):
                message.toolResults.append(ToolResultDisplay(
                    toolUseId: resultBlock.toolUseId,
                    content: resultBlock.content,
                    isError: resultBlock.isError
                ))

            case .thinking(let thinkingBlock):
                message.thinking = thinkingBlock.thinking
            }
        }
    }

    /// Handle user message: accumulate tool results from user content blocks.
    private func handleUserMessage(_ userMsg: UserMessage, message: inout ChatMessage) {
        for block in userMsg.content {
            switch block {
            case .toolResult(let resultBlock):
                message.toolResults.append(ToolResultDisplay(
                    toolUseId: resultBlock.toolUseId,
                    content: resultBlock.content,
                    isError: resultBlock.isError
                ))
            default:
                break
            }
        }
    }

    /// Handle stream event: append character-by-character deltas for text, JSON, and thinking.
    private func handleStreamEvent(_ event: StreamEventMessage, message: inout ChatMessage) {
        guard let delta = event.delta else { return }

        switch delta {
        case .textDelta(let text):
            message.text += text

        case .inputJsonDelta(let json):
            // Accumulate partial JSON on last tool call's inputPreview
            if !message.toolCalls.isEmpty {
                let lastIndex = message.toolCalls.count - 1
                let existing = message.toolCalls[lastIndex].inputPreview ?? ""
                message.toolCalls[lastIndex].inputPreview = existing + json
            }

        case .thinkingDelta(let thinking):
            message.thinking = (message.thinking ?? "") + thinking
        }
    }
}
