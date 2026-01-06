import SwiftUI
import SwiftData

struct HistoryDrawerView: View {
    // All sessions, sorted by last message time
    @Query(sort: \ChatSession.lastMessageAt, order: .reverse)
    private var allSessions: [ChatSession]
    
    // ✅ REMOVED: @Query private var allMessages (no longer needed!)
    
    @Environment(\.modelContext) private var modelContext
    
    // Callbacks to ContentView
    var onSelectSession: (ChatSession) -> Void
    var onNewChat: () -> Void
    
    // Group sessions by date for sectioning
    var groupedSessions: [String: [ChatSession]] {
        Dictionary(grouping: allSessions) { session in
            session.lastMessageAt.dateGroupHeader()
        }
    }
    
    var groupOrder: [String] {
        let order = ["Today", "Yesterday"]
        return groupedSessions.keys.sorted { key1, key2 in
            if let index1 = order.firstIndex(of: key1),
               let index2 = order.firstIndex(of: key2) {
                return index1 < index2
            }
            if order.contains(key1) { return true }
            if order.contains(key2) { return false }
            return key1 > key2
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header
            HStack {
                Text("History")
                    .font(.title).bold()
                Spacer()
                Button(action: onNewChat) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
                }
            }
            .padding()
            
            // Session List
            List {
                ForEach(groupOrder, id: \.self) { groupKey in
                    Section(header: Text(groupKey)) {
                        ForEach(groupedSessions[groupKey]!) { session in
                            SessionRow(session: session, onSelect: onSelectSession)
                        }
                        .onDelete { indexSet in
                            deleteSession(for: groupKey, at: indexSet)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemGray6))
    }
    
    // ✅ MASSIVELY SIMPLIFIED: Cascade delete handles messages automatically
    private func deleteSession(for group: String, at offsets: IndexSet) {
        guard let sessionsInGroup = groupedSessions[group] else { return }
        
        for index in offsets {
            let sessionToDelete = sessionsInGroup[index]
            
            // Prevent deleting active session
            guard !sessionToDelete.isActive else {
                print("⚠️ Cannot delete active session")
                continue
            }
            
            // ✅ ONE LINE: SwiftData cascade deletes all messages automatically
            modelContext.delete(sessionToDelete)
            print("🗑️ Deleted session: \(sessionToDelete.title)")
        }
        
        try? modelContext.save()
    }
}

// MARK: - Session Row View

struct SessionRow: View {
    @Bindable var session: ChatSession
    var onSelect: (ChatSession) -> Void
    
    @State private var showingRename = false
    @State private var newTitle = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .lineLimit(1)
                Text(session.lastMessageAt.relativeTimeString())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            if session.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(session)
        }
        .onLongPressGesture {
            newTitle = session.title
            showingRename = true
        }
        .alert("Rename Chat", isPresented: $showingRename) {
            TextField("New title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                session.title = newTitle
            }
        }
    }
}