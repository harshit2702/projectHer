import SwiftUI
import SwiftData

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
    @State private var showingMemoryDashboard = false
    @State private var showingMemorySearch = false
    @State private var showingLinkAlert = false
    @State private var linkAlertMessage = ""
    
    // Linking State
    @State private var linkingMode = false
    @State private var sourceMemoryForLinking: ChatMessage?
    
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
                    
                    Spacer()
                    
                    // ✅ Connection Status Indicator
                    Circle()
                        .fill(connectionStatus.color)
                        .frame(width: 10, height: 10)
                        .onTapGesture {
                            // Show connection status alert
                        }
                    
                    Button(action: { showingHealth = true }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: { showingMemoryDashboard = true }) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)
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
                HStack {
                    TextField("Talk to her...", text: $inputText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: { sendMessage(text: inputText) }) {
                        Image(systemName: "paperplane.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty || isTyping)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
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
        }
        .sheet(isPresented: $showingHealth) {
            HealthView()
        }
        .sheet(isPresented: $showingMemoryDashboard) {
            MemoryDashboardView()
        }
        .sheet(isPresented: $showingMemorySearch, onDismiss: {
            // Reset linking mode on dismiss
            linkingMode = false
            sourceMemoryForLinking = nil
        }) {
            MemorySearchView(
                selectionMode: linkingMode,
                onSelect: { targetMemory in
                    if linkingMode {
                        linkMemories(
                            source: sourceMemoryForLinking?.serverId,
                            target: targetMemory.id
                        )
                        showingMemorySearch = false // Dismiss sheet
                    }
                }
            )
        }
        .alert("Linking Error", isPresented: $showingLinkAlert) {
            Button("OK", role: .cancel) { }
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
        
        guard let url = URL(string: "\(serverURL)/memory/resolve?memory_id=\(memoryId)") else { return }
        
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
        
        // Create message with session relationship
        let userMsg = ChatMessage(text: messageText, isUser: true, session: session)
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
        
        guard let url = URL(string: "\(serverURL)/chat") else {
            userMsg.status = .failed
            connectionStatus = .disconnected
            isTyping = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 30
        
        let payload = ChatRequest(
            message: messageText, 
            history: historyItems,
            context_chain_id: session.contextChainId
        )
        request.httpBody = try? JSONEncoder().encode(payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTyping = false
                
                // Network error
                if let error = error {
                    userMsg.status = .failed
                    connectionStatus = .disconnected
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }
                
                // HTTP status check
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        connectionStatus = .connected
                    case 403:
                        userMsg.status = .failed
                        connectionStatus = .authError
                        return
                    case 500...599:
                        userMsg.status = .failed
                        connectionStatus = .serverError
                        return
                    default:
                        userMsg.status = .failed
                        connectionStatus = .disconnected
                        return
                    }
                }
                
                // Parse response
                if let data = data,
                   let response = try? JSONDecoder().decode(ServerResponse.self, from: data) {
                    userMsg.status = .sent
                    
                    // Create AI reply with session relationship
                    let reply = ChatMessage(
                        text: response.reply, 
                        isUser: false, 
                        session: session,
                        usedContext: response.context_used,
                        serverId: response.memory_id,
                        type: response.type
                    )
                    reply.status = .sent
                    modelContext.insert(reply)
                    
                    // Add to relationship
                    session.messages.append(reply)
                    session.lastMessageAt = Date()
                    
                    print("✅ Message sent and reply received")
                } else {
                    userMsg.status = .failed
                    connectionStatus = .serverError
                    print("❌ Failed to parse server response")
                }
            }
        }.resume()
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
