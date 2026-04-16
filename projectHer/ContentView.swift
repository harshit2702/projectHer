import AVFoundation
import SwiftData
import SwiftUI

struct ContentView: View {
    // 1. Database Connection
    @Environment(\.modelContext) private var modelContext

    // 2. Session Query (lightweight - only metadata)
    @Query(sort: \ChatSession.lastMessageAt, order: .reverse)
    private var allSessions: [ChatSession]

    // ✅ REMOVED: @Query private var allMessages: [ChatMessage]
    // We no longer load ALL messages into memory!

    // 3. UI State
    @State private var activeSessionID: UUID?
    @State private var showingDrawer = false
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var connectionStatus: ConnectionStatus = .checking
    @State private var showingHealth = false
    @State private var showingAvatar = false
    @State private var showingMemoryDashboard = false
    @State private var showingMemorySearch = false
    @State private var showingLinkAlert = false
    @State private var linkAlertMessage = ""

    // Voice & STT/TTS
    @State private var voiceMode = false
    @State private var autoSpeakReplies = true

    @StateObject private var stt = LiveSTT(localeId: "en-IN")
    @StateObject private var tts = TTSManager()

    @State private var showingSettings = false
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = ""
    @AppStorage("voicePitch") private var voicePitch: Double = 1.0
    @AppStorage("voiceRate") private var voiceRate: Double = Double(
        AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("silenceDuration") private var silenceDuration: Double = 1.5
    @AppStorage("showEmotionalState") private var showEmotionalState: Bool = true

    // Linking State
    @State private var linkingMode = false
    @State private var sourceMemoryForLinking: ChatMessage?
    
    // 🆕 Deep Link Action (from notification tap)
    @Binding var pendingDeepLinkAction: ProjectHerApp.DeepLinkAction?

    // 🆕 Initialize with optional deep link binding
    init(pendingDeepLinkAction: Binding<ProjectHerApp.DeepLinkAction?> = .constant(nil)) {
        _pendingDeepLinkAction = pendingDeepLinkAction
    }

    // Derived active session from Query to ensure consistency
    var activeSession: ChatSession? {
        if let id = activeSessionID {
            return allSessions.first(where: { $0.id == id })
        }
        return nil
    }

    // ✅ OPTIMIZED: Get messages directly from active session's relationship
    var sessionMessages: [ChatMessage] {
        guard let session = activeSession else { return [] }
        return session.messages.sorted { $0.timestamp < $1.timestamp }
    }

    // Group messages by date and sort groups chronologically
    var messagesByDate: [(key: String, value: [ChatMessage])] {
        let grouped = Dictionary(grouping: sessionMessages) { message in
            message.timestamp.dateGroupHeader()
        }

        return grouped.sorted { (group1, group2) in
            let date1 = group1.value.first?.timestamp ?? Date.distantPast
            let date2 = group2.value.first?.timestamp ?? Date.distantPast
            return date1 < date2
        }
    }

    // ⚠️ Configuration moved to AppConfig.swift
    let serverURL = AppConfig.serverURL
    let apiKey = AppConfig.apiKey
    private let maxChatDeliveryAttempts = 3
    private let baseChatRetryDelay: Double = 1.5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main chat view
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { showingDrawer.toggle() }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Text(activeSession?.title ?? "Pandu ❤️")
                            .font(.title2).bold()

                        if showEmotionalState {
                            VStack(spacing: 2) {
                                Text(EmotionEngine.shared.getCurrentMood())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.purple)

                                HStack(spacing: 2) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                    Text(
                                        String(
                                            format: "%.1f", EmotionEngine.shared.getCurrentEnergy())
                                    )
                                    .font(.system(size: 8))
                                }
                                .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        // ✅ Connection Status Indicator
                        Circle()
                            .fill(connectionStatus.color)
                            .frame(width: 10, height: 10)
                            .onTapGesture {
                                checkConnection()
                            }

                        Menu {
                            Button(action: { showingHealth = true }) {
                                Label("Server Health", systemImage: "info.circle")
                            }

                            Button(action: { showingAvatar = true }) {
                                Label("Video Call", systemImage: "video.fill")
                            }

                            Button(action: { showingMemoryDashboard = true }) {
                                Label("Memory Dashboard", systemImage: "brain.head.profile")
                            }

                            Button(action: { showingSettings = true }) {
                                Label("Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal)

                    // Chat Scroll Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(messagesByDate, id: \.key) { group in
                                    // Date separator
                                    Text(group.key)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 8)

                                    // Messages for this date
                                    ForEach(group.value) { msg in
                                        messageView(for: msg)
                                    }
                                }

                                // Typing indicator
                                if isTyping {
                                    HStack {
                                        TypingIndicatorView()
                                        Spacer()
                                    }
                                    .id("TYPING_INDICATOR_ID")
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: sessionMessages.count) { _, _ in
                            if let last = sessionMessages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: activeSessionID) { _, _ in
                            // Scroll to bottom when switching chats
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let last = sessionMessages.last {
                                    withAnimation {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: isTyping) { _, isTyping in
                            if isTyping {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("TYPING_INDICATOR_ID", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    // Input Field
                    InputBarView(
                        inputText: $inputText,
                        isTyping: isTyping,
                        isSpeaking: tts.isSpeaking,
                        voiceMode: $voiceMode,
                        transcript: stt.transcript,
                        isListening: stt.isListening,
                        onSendText: { sendMessage(text: inputText) },
                        onEnterVoiceMode: {
                            Task {
                                do {
                                    voiceMode = true
                                    try await stt.requestPermissions()
                                    try stt.start()
                                    // 🆕 Start CallKit call for voice mode (appears in Phone Recents)
                                    try? await BackgroundCallService.shared.startCall(isVideo: false)
                                } catch {
                                    voiceMode = false
                                }
                            }
                        },
                        onToggleMic: {
                            if stt.isListening {
                                stt.stop()
                            } else {
                                Task {
                                    try? await stt.requestPermissions()
                                    try? stt.start()
                                }
                            }
                        },
                        onCancelVoice: {
                            stt.stop()
                            voiceMode = false
                            // 🆕 End CallKit call when voice mode is cancelled
                            Task {
                                await BackgroundCallService.shared.endCall()
                            }
                        }
                    )
                    
                    // 🆕 Mini call indicator when call is running in background
                    MiniCallView(
                        onTap: {
                            // Return to video call view
                            showingAvatar = true
                        },
                        onEndCall: {
                            Task {
                                await BackgroundCallService.shared.endCall()
                            }
                        }
                    )
                    .padding(.bottom, 80)
                }

                // Drawer overlay
                if showingDrawer {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingDrawer = false }

                    HistoryDrawerView(
                        onSelectSession: { session in
                            switchToSession(session)
                            showingDrawer = false
                        },
                        onNewChat: {
                            createNewChat()
                            showingDrawer = false
                        }
                    )
                    .frame(width: geometry.size.width * 0.8)
                    .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.easeInOut, value: showingDrawer)
        .onAppear {
            loadOrCreateActiveSession()
            checkConnection()
            EmotionEngine.shared.wakeUp()

            // Sync silence duration
            stt.silenceSeconds = silenceDuration

            stt.onFinal = { finalText in
                DispatchQueue.main.async {
                    // Temporarily stop listening while processing/sending
                    // We stay in voiceMode so we can resume later if needed
                    self.sendMessage(text: finalText)
                }
            }

            tts.onFinish = {
                // Hands-free: if we are still in voice mode, resume listening
                if self.voiceMode {
                    Task { try? self.stt.start() }
                }
            }
        }
        // 🆕 Handle deep link actions from notifications
        .onChange(of: pendingDeepLinkAction) { _, action in
            if let action = action {
                handleDeepLinkAction(action)
                pendingDeepLinkAction = nil
            }
        }
        .onChange(of: silenceDuration) { _, newValue in
            stt.silenceSeconds = newValue
        }
        .sheet(isPresented: $showingHealth) {
            HealthView()
        }
        .fullScreenCover(isPresented: $showingAvatar) {
            AvatarView(tts: tts, stt: stt, voiceMode: $voiceMode)
        }
        .sheet(isPresented: $showingMemoryDashboard) {
            MemoryDashboardView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(tts: tts)
        }
        .sheet(
            isPresented: $showingMemorySearch,
            onDismiss: {
                // Reset linking mode on dismiss
                linkingMode = false
                sourceMemoryForLinking = nil
            }
        ) {
            MemorySearchView(
                selectionMode: linkingMode,
                onSelect: { targetMemory in
                    if linkingMode {
                        linkMemories(
                            source: sourceMemoryForLinking?.serverId,
                            target: targetMemory.id
                        )
                        showingMemorySearch = false  // Dismiss sheet
                    }
                }
            )
        }
        .alert("Linking Error", isPresented: $showingLinkAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkAlertMessage)
        }
    }

    @ViewBuilder
    private func messageView(for msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer() }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .padding()
                    .background(msg.isUser ? Color.blue.opacity(0.8) : Color.pink.opacity(0.2))
                    .foregroundColor(msg.isUser ? .white : .primary)
                    .cornerRadius(16)
                    .contextMenu {
                        Button(action: { showLinkingSheet(for: msg) }) {
                            Label("Link Memory", systemImage: "link")
                        }

                        if msg.status == .failed {
                            Button(action: { retryMessage(msg) }) {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                        }
                        Button(role: .destructive, action: { deleteMessage(msg) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if msg.status == .failed {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                                .offset(x: 4, y: 4)
                        }
                    }

                // Timestamp
                Text(msg.timestamp.relativeTimeString())
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)

                if !msg.isUser && msg.type == "future_plan" {
                    Button(action: { markAsResolved(msg) }) {
                        Label("Mark Complete", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

                if !msg.isUser && msg.usedContext {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                        Text("Used memories")
                            .font(.caption2)
                    }
                    .foregroundColor(.purple.opacity(0.7))
                    .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: 250, alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer() }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .id(msg.id)
    }

    // MARK: - Session Management

    func loadOrCreateActiveSession() {
        // Try to find existing active session
        if let active = allSessions.first(where: { $0.isActive }) {
            activeSessionID = active.id
        } else {
            // No active session exists - create one
            let newSession = ChatSession()
            modelContext.insert(newSession)
            // Save to generate ID
            try? modelContext.save()
            activeSessionID = newSession.id
        }
    }

    // ✅ FIXED: Proper session switching with ID
    func switchToSession(_ session: ChatSession) {
        // Deactivate all sessions
        for s in allSessions {
            s.isActive = false
        }

        // Activate target session
        session.isActive = true

        // Update active session ID
        activeSessionID = session.id

        // Save changes immediately
        try? modelContext.save()
    }

    func createNewChat() {
        print("🆕 Creating new chat")

        // Deactivate current session
        if let current = activeSession {
            current.isActive = false
        }

        // Create new session
        let newSession = ChatSession()
        modelContext.insert(newSession)

        // Save immediately to get ID
        try? modelContext.save()

        activeSessionID = newSession.id
        inputText = ""

        print("✅ Created new session: \(newSession.title)")
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep link actions (e.g., from notifications)
    func handleDeepLinkAction(_ action: ProjectHerApp.DeepLinkAction) {
        switch action {
        case .openNewChat:
            print("📱 Deep link: Opening new chat from notification")
            createNewChat()
        case .openChat(let sessionId):
            if let id = sessionId, let session = allSessions.first(where: { $0.id == id }) {
                print("📱 Deep link: Opening specific chat \(id)")
                switchToSession(session)
            } else {
                print("📱 Deep link: Session not found, creating new chat")
                createNewChat()
            }
        }
    }

    // MARK: - Message Handling

    func showLinkingSheet(for message: ChatMessage) {
        sourceMemoryForLinking = message
        linkingMode = true
        showingMemorySearch = true
    }

    func linkMemories(source: String?, target: String) {
        guard let sourceId = source else {
            linkAlertMessage = "This message has no memory_id yet"
            showingLinkAlert = true
            return
        }

        let payload = MemoryLinkRequest(
            source_id: sourceId,
            target_id: target
        )

        guard let url = URL(string: "\(serverURL)/memory/link") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if error == nil {
                    // Show success feedback
                    print("✅ Memories linked!")
                    // A simple haptic or visual feedback could be added here
                }
            }
        }.resume()
    }

    func markAsResolved(_ message: ChatMessage) {
        guard let memoryId = message.serverId else { return }

        guard let url = URL(string: "\(serverURL)/memory/resolve?memory_id=\(memoryId)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        URLSession.shared.dataTask(with: request) { _, _, error in
            if error == nil {
                print("✅ Task marked as resolved")
            }
        }.resume()
    }

    func deleteMessage(_ message: ChatMessage) {
        modelContext.delete(message)
        print("🗑️ Deleted message")
    }

    func retryMessage(_ message: ChatMessage) {
        let textToRetry = message.text

        // Delete failed message
        modelContext.delete(message)

        // Resend
        sendMessage(text: textToRetry)
    }

    // ✅ FIXED: Pass session object instead of ID
    func sendMessage(text: String) {
        guard let session = activeSession else {
            print("❌ No active session")
            return
        }

        let messageText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }

        let clientMessageId = UUID().uuidString

        // 1. Update Emotion Engine
        EmotionEngine.shared.processUserMessage(messageText)

        // Create message with session relationship
        let userMsg = ChatMessage(
            text: messageText,
            isUser: true,
            session: session,
            clientMessageId: clientMessageId
        )
        userMsg.status = .sending
        modelContext.insert(userMsg)

        // ✅ IMPORTANT: Explicitly add to relationship for instant UI update
        session.messages.append(userMsg)
        session.lastMessageAt = Date()

        inputText = ""
        isTyping = true

        // Build history from session messages
        let historyItems = sessionMessages.suffix(5).map {
            HistoryItem(role: $0.isUser ? "user" : "assistant", content: $0.text)
        }

        sendChatRequest(
            session: session,
            userMsg: userMsg,
            messageText: messageText,
            historyItems: historyItems,
            clientMessageId: clientMessageId,
            attempt: 1
        )
    }

    private func sendChatRequest(
        session: ChatSession,
        userMsg: ChatMessage,
        messageText: String,
        historyItems: [HistoryItem],
        clientMessageId: String,
        attempt: Int
    ) {
        guard let url = URL(string: "\(serverURL)/chat") else {
            finalizeChatFailure(
                userMsg: userMsg,
                connection: .disconnected,
                reason: "invalid chat URL"
            )
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 35

        let payload = ChatRequest(
            message: messageText,
            history: historyItems,
            context_chain_id: session.contextChainId,
            client_message_id: clientMessageId,
            mood: EmotionEngine.shared.getCurrentMood(),
            tone_instruction: EmotionEngine.shared.getToneInstruction()
        )
        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.scheduleChatRetryOrFail(
                        session: session,
                        userMsg: userMsg,
                        messageText: messageText,
                        historyItems: historyItems,
                        clientMessageId: clientMessageId,
                        attempt: attempt,
                        reason: "network error: \(error.localizedDescription)",
                        fallbackConnection: .disconnected,
                        retryDelay: nil
                    )
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        break
                    case 403:
                        self.finalizeChatFailure(
                            userMsg: userMsg,
                            connection: .authError,
                            reason: "authentication failed"
                        )
                        return
                    case 500...599:
                        self.scheduleChatRetryOrFail(
                            session: session,
                            userMsg: userMsg,
                            messageText: messageText,
                            historyItems: historyItems,
                            clientMessageId: clientMessageId,
                            attempt: attempt,
                            reason: "server error \(httpResponse.statusCode)",
                            fallbackConnection: .serverError,
                            retryDelay: nil
                        )
                        return
                    default:
                        self.scheduleChatRetryOrFail(
                            session: session,
                            userMsg: userMsg,
                            messageText: messageText,
                            historyItems: historyItems,
                            clientMessageId: clientMessageId,
                            attempt: attempt,
                            reason: "unexpected status \(httpResponse.statusCode)",
                            fallbackConnection: .disconnected,
                            retryDelay: nil
                        )
                        return
                    }
                }

                guard let data,
                    let serverResponse = try? JSONDecoder().decode(ServerResponse.self, from: data)
                else {
                    self.scheduleChatRetryOrFail(
                        session: session,
                        userMsg: userMsg,
                        messageText: messageText,
                        historyItems: historyItems,
                        clientMessageId: clientMessageId,
                        attempt: attempt,
                        reason: "failed to parse server response",
                        fallbackConnection: .serverError,
                        retryDelay: nil
                    )
                    return
                }

                let status = (serverResponse.status ?? "success").lowercased()
                if status == "processing" {
                    self.scheduleChatRetryOrFail(
                        session: session,
                        userMsg: userMsg,
                        messageText: messageText,
                        historyItems: historyItems,
                        clientMessageId: clientMessageId,
                        attempt: attempt,
                        reason: "server still processing",
                        fallbackConnection: .serverError,
                        retryDelay: Double(max(1, serverResponse.retry_after_seconds ?? 2))
                    )
                    return
                }

                guard status == "success" else {
                    self.scheduleChatRetryOrFail(
                        session: session,
                        userMsg: userMsg,
                        messageText: messageText,
                        historyItems: historyItems,
                        clientMessageId: clientMessageId,
                        attempt: attempt,
                        reason: "server returned \(status)",
                        fallbackConnection: .serverError,
                        retryDelay: nil
                    )
                    return
                }

                self.isTyping = false
                self.connectionStatus = .connected
                userMsg.status = .sent

                let effectiveClientMessageId = serverResponse.client_message_id ?? clientMessageId
                let hasExistingReply = session.messages.contains {
                    !$0.isUser && $0.clientMessageId == effectiveClientMessageId
                }

                if !hasExistingReply {
                    let didUseMemory = serverResponse.context_used
                        && (serverResponse.memory_items_used ?? 0) > 0

                    let reply = ChatMessage(
                        text: serverResponse.reply,
                        isUser: false,
                        session: session,
                        usedContext: didUseMemory,
                        serverId: serverResponse.memory_id,
                        type: serverResponse.type,
                        clientMessageId: effectiveClientMessageId
                    )
                    reply.status = .sent
                    self.modelContext.insert(reply)

                    session.messages.append(reply)
                    session.lastMessageAt = Date()

                    if serverResponse.outfit_changed == true, let outfitId = serverResponse.outfit_changed_to {
                        if let newOutfit = WardrobeManager.shared.wardrobe.first(where: {
                            $0.id == outfitId
                        }) {
                            WardrobeManager.shared.currentOutfit.base = newOutfit
                            print("👗 Outfit synced from chat: \(outfitId)")
                        }
                    }

                    print("✅ Message delivered with id \(effectiveClientMessageId)")

                    if self.autoSpeakReplies && (self.voiceMode || self.showingAvatar) {
                        self.stt.stop()
                        self.tts.speak(
                            serverResponse.reply,
                            voiceId: self.selectedVoiceId,
                            pitchMultiplier: Float(self.voicePitch),
                            rate: Float(self.voiceRate)
                        )
                    }
                }

                if serverResponse.ack_required == true || serverResponse.client_message_id != nil {
                    self.sendChatAck(clientMessageId: effectiveClientMessageId)
                }
            }
        }.resume()
    }

    private func scheduleChatRetryOrFail(
        session: ChatSession,
        userMsg: ChatMessage,
        messageText: String,
        historyItems: [HistoryItem],
        clientMessageId: String,
        attempt: Int,
        reason: String,
        fallbackConnection: ConnectionStatus,
        retryDelay: Double?
    ) {
        if attempt < maxChatDeliveryAttempts {
            let delay = retryDelay ?? (baseChatRetryDelay * pow(2.0, Double(attempt - 1)))
            print("↻ Chat retry \(attempt + 1)/\(maxChatDeliveryAttempts) for \(clientMessageId): \(reason)")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.sendChatRequest(
                    session: session,
                    userMsg: userMsg,
                    messageText: messageText,
                    historyItems: historyItems,
                    clientMessageId: clientMessageId,
                    attempt: attempt + 1
                )
            }
            return
        }

        finalizeChatFailure(userMsg: userMsg, connection: fallbackConnection, reason: reason)
        triggerChatFallbackNotification(clientMessageId: clientMessageId)
    }

    private func finalizeChatFailure(userMsg: ChatMessage, connection: ConnectionStatus, reason: String) {
        userMsg.status = .failed
        connectionStatus = connection
        isTyping = false
        print("❌ Chat delivery failed: \(reason)")
    }

    private func sendChatAck(clientMessageId: String) {
        guard let url = URL(string: "\(serverURL)/chat/ack") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 8
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "client_message_id": clientMessageId
        ])

        URLSession.shared.dataTask(with: request).resume()
    }

    private func triggerChatFallbackNotification(clientMessageId: String) {
        guard let url = URL(string: "\(serverURL)/chat/fallback-notification") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 8
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "client_message_id": clientMessageId
        ])

        URLSession.shared.dataTask(with: request).resume()
    }

    // ✅ NEW: Dedicated connection check (cleaner than hijacking sendMessage)
    func checkConnection() {
        connectionStatus = .checking

        guard let url = URL(string: "\(serverURL)/health") else {
            connectionStatus = .disconnected
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    connectionStatus = .disconnected
                } else if let httpResponse = response as? HTTPURLResponse {
                    connectionStatus = (httpResponse.statusCode == 200) ? .connected : .serverError
                }
            }
        }.resume()
    }
}
