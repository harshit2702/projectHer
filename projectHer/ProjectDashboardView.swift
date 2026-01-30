//
//  ProjectDashboardView.swift
//  projectHer
//
//  Feature #2: iOS Project Dashboard
//  View to manage Pandu's "Deep Work" projects
//

import SwiftUI

// MARK: - Data Models

struct Project: Identifiable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String
    let emotional_investment: String
    let started: TimeInterval
    var progress: Double
    let last_update: TimeInterval
    let milestones: [Milestone]
    let blocked: Bool
    let failure_count: Int
    
    // Enhanced display info from server
    var hours_since_update: Double?
    var progress_percent: Int?
    var milestone_summary: String?
    var needs_attention: Bool?
    
    var progressPercent: Int {
        progress_percent ?? Int(progress * 100)
    }
    
    var emotionalInvestmentEmoji: String {
        switch emotional_investment {
        case "very_high": return "🔥"
        case "high": return "❤️"
        case "medium": return "💛"
        case "low": return "💤"
        default: return "💭"
        }
    }
    
    var typeIcon: String {
        switch type {
        case "research": return "brain.head.profile"
        case "creative_writing": return "pencil.and.scribble"
        case "skill_learning": return "graduationcap"
        case "reading": return "book"
        default: return "folder"
        }
    }
}

struct Milestone: Codable {
    let name: String
    let threshold: Double
    let completed: Bool
    let completed_at: TimeInterval?
}

struct ProjectListResponse: Codable {
    let projects: [Project]
    let total: Int
    let last_synthesis: TimeInterval
}

struct ProjectDetailResponse: Codable {
    let project: Project
    let ledger_content: String
    let brainstorm_content: String
    let ledger_file: String?
    let brainstorm_file: String?
}

struct SynthesisResponse: Codable {
    let status: String
    let message: String?
    let emotional_beats: [String]?
    let user_model_update: String?
    let summary: String?
    let reason: String?
}

// MARK: - Main Dashboard View

struct ProjectDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddProject = false
    @State private var selectedProject: Project?
    @State private var isSynthesizing = false
    @State private var synthesisResult: SynthesisResponse?
    @State private var showingSynthesisResult = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading projects...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadProjects() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if projects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No active projects")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Pandu doesn't have any ongoing projects yet.")
                            .foregroundColor(.secondary)
                        Button("Add Project") {
                            showingAddProject = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        // Weekly Synthesis Section
                        Section {
                            Button(action: {
                                Task { await triggerWeeklySynthesis() }
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("Run Weekly Memory Synthesis")
                                    Spacer()
                                    if isSynthesizing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(isSynthesizing)
                        } header: {
                            Text("Gemini Synthesis")
                        } footer: {
                            Text("Uses Gemini to summarize weekly memories into emotional beats and user insights.")
                        }
                        
                        // Projects Section
                        Section {
                            ForEach(projects) { project in
                                ProjectRowView(project: project)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedProject = project
                                    }
                            }
                        } header: {
                            Text("Active Projects (\(projects.count))")
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadProjects()
            }
        }
        .task {
            await loadProjects()
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView { newProject in
                projects.insert(newProject, at: 0)
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project) {
                Task { await loadProjects() }
            }
        }
        .alert("Synthesis Complete", isPresented: $showingSynthesisResult) {
            Button("OK") { synthesisResult = nil }
        } message: {
            if let result = synthesisResult {
                if result.status == "success" {
                    Text(result.summary ?? "Weekly synthesis completed successfully!")
                } else {
                    Text(result.reason ?? result.message ?? "Synthesis completed")
                }
            }
        }
    }
    
    private func loadProjects() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await ProjectAPIService.shared.listProjects()
            await MainActor.run {
                projects = response.projects
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load projects: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func triggerWeeklySynthesis() async {
        isSynthesizing = true
        
        do {
            let result = try await ProjectAPIService.shared.triggerSynthesis(projectId: nil)
            await MainActor.run {
                synthesisResult = result
                showingSynthesisResult = true
                isSynthesizing = false
            }
        } catch {
            await MainActor.run {
                synthesisResult = SynthesisResponse(
                    status: "error",
                    message: error.localizedDescription,
                    emotional_beats: nil,
                    user_model_update: nil,
                    summary: nil,
                    reason: error.localizedDescription
                )
                showingSynthesisResult = true
                isSynthesizing = false
            }
        }
    }
}

// MARK: - Project Row View

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: project.typeIcon)
                    .foregroundColor(.accentColor)
                Text(project.title)
                    .font(.headline)
                Spacer()
                Text(project.emotionalInvestmentEmoji)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * project.progress, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(project.progressPercent)% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if project.blocked {
                    Label("Blocked", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if project.needs_attention == true {
                    Label("Stale", systemImage: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                if let summary = project.milestone_summary {
                    Text("📍 \(summary)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var progressColor: Color {
        if project.blocked {
            return .orange
        } else if project.progress >= 0.75 {
            return .green
        } else if project.progress >= 0.5 {
            return .blue
        } else {
            return .accentColor
        }
    }
}

// MARK: - Add Project View

struct AddProjectView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var type = "research"
    @State private var emotionalInvestment = "medium"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    let onAdd: (Project) -> Void
    
    let projectTypes = [
        ("research", "Research", "brain.head.profile"),
        ("creative_writing", "Creative Writing", "pencil.and.scribble"),
        ("skill_learning", "Skill Learning", "graduationcap"),
        ("reading", "Reading", "book")
    ]
    
    let investmentLevels = [
        ("very_high", "Very High 🔥"),
        ("high", "High ❤️"),
        ("medium", "Medium 💛"),
        ("low", "Low 💤")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Describe the project...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Project Type")) {
                    Picker("Type", selection: $type) {
                        ForEach(projectTypes, id: \.0) { item in
                            Label(item.1, systemImage: item.2)
                                .tag(item.0)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Emotional Investment")) {
                    Picker("Investment", selection: $emotionalInvestment) {
                        ForEach(investmentLevels, id: \.0) { level in
                            Text(level.1).tag(level.0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task { await addProject() }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func addProject() async {
        isSubmitting = true
        errorMessage = nil
        
        do {
            let newProject = try await ProjectAPIService.shared.addProject(
                type: type,
                title: title,
                description: description,
                emotionalInvestment: emotionalInvestment
            )
            await MainActor.run {
                onAdd(newProject)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    let project: Project
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var detail: ProjectDetailResponse?
    @State private var isLoading = true
    @State private var isSynthesizing = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var synthesisMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: project.typeIcon)
                                .font(.title)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(project.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(project.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(project.emotionalInvestmentEmoji)
                                .font(.title)
                        }
                        
                        Text(project.description)
                            .foregroundColor(.secondary)
                        
                        // Progress
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Progress")
                                Spacer()
                                Text("\(project.progressPercent)%")
                                    .fontWeight(.semibold)
                            }
                            ProgressView(value: project.progress)
                                .tint(project.blocked ? .orange : .accentColor)
                        }
                        
                        // Status badges
                        HStack {
                            if project.blocked {
                                Label("Blocked", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if let summary = project.milestone_summary {
                                Label(summary, systemImage: "flag.checkered")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Run Gemini Button
                    Button(action: {
                        Task { await runGeminiSynthesis() }
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Run Gemini Deep Work")
                            Spacer()
                            if isSynthesizing {
                                ProgressView()
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isSynthesizing)
                    
                    if let message = synthesisMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    // Work Log (Ledger)
                    if isLoading {
                        ProgressView("Loading details...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let detail = detail {
                        if !detail.ledger_content.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work Log")
                                    .font(.headline)
                                
                                ScrollView {
                                    Text(detail.ledger_content)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 300)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        if !detail.brainstorm_content.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Brainstorm Notes")
                                    .font(.headline)
                                
                                ScrollView {
                                    Text(detail.brainstorm_content)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 200)
                                .padding()
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Delete Button
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Archive Project")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
            }
            .navigationTitle("Project Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .task {
            await loadDetail()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProjectView(project: project) {
                onUpdate()
                dismiss()
            }
        }
        .alert("Archive Project?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                Task { await deleteProject() }
            }
        } message: {
            Text("This will archive the project. It won't be deleted permanently.")
        }
    }
    
    private func loadDetail() async {
        do {
            let response = try await ProjectAPIService.shared.getProjectDetail(projectId: project.id)
            await MainActor.run {
                detail = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func runGeminiSynthesis() async {
        isSynthesizing = true
        synthesisMessage = nil
        
        do {
            let result = try await ProjectAPIService.shared.triggerSynthesis(projectId: project.id)
            await MainActor.run {
                synthesisMessage = result.message ?? "Deep work session completed!"
                isSynthesizing = false
                // Reload detail to see new content
                Task { await loadDetail() }
            }
        } catch {
            await MainActor.run {
                synthesisMessage = "Failed: \(error.localizedDescription)"
                isSynthesizing = false
            }
        }
    }
    
    private func deleteProject() async {
        do {
            _ = try await ProjectAPIService.shared.deleteProject(projectId: project.id)
            await MainActor.run {
                onUpdate()
                dismiss()
            }
        } catch {
            // Handle error
        }
    }
}

// MARK: - Edit Project View

struct EditProjectView: View {
    let project: Project
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var emotionalInvestment: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    let investmentLevels = [
        ("very_high", "Very High 🔥"),
        ("high", "High ❤️"),
        ("medium", "Medium 💛"),
        ("low", "Low 💤")
    ]
    
    init(project: Project, onUpdate: @escaping () -> Void) {
        self.project = project
        self.onUpdate = onUpdate
        _title = State(initialValue: project.title)
        _description = State(initialValue: project.description)
        _emotionalInvestment = State(initialValue: project.emotional_investment)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Emotional Investment")) {
                    Picker("Investment", selection: $emotionalInvestment) {
                        ForEach(investmentLevels, id: \.0) { level in
                            Text(level.1).tag(level.0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await updateProject() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func updateProject() async {
        isSubmitting = true
        errorMessage = nil
        
        do {
            _ = try await ProjectAPIService.shared.updateProject(
                projectId: project.id,
                title: title,
                description: description,
                emotionalInvestment: emotionalInvestment
            )
            await MainActor.run {
                onUpdate()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

// MARK: - Project API Service

class ProjectAPIService {
    static let shared = ProjectAPIService()
    
    private let baseURL = AppConfig.serverURL
    private let apiKey = AppConfig.apiKey
    
    private init() {}
    
    func listProjects() async throws -> ProjectListResponse {
        guard let url = URL(string: "\(baseURL)/projects/list") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ProjectListResponse.self, from: data)
    }
    
    func getProjectDetail(projectId: String) async throws -> ProjectDetailResponse {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ProjectDetailResponse.self, from: data)
    }
    
    func addProject(type: String, title: String, description: String, emotionalInvestment: String) async throws -> Project {
        guard let url = URL(string: "\(baseURL)/admin/projects/add") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let body: [String: Any] = [
            "type": type,
            "title": title,
            "description": description,
            "emotional_investment": emotionalInvestment
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Server returns {status, project_id}, we need to fetch the full project
        let response = try JSONDecoder().decode([String: String].self, from: data)
        
        // Return a minimal project object
        return Project(
            id: response["project_id"] ?? UUID().uuidString,
            type: type,
            title: title,
            description: description,
            emotional_investment: emotionalInvestment,
            started: Date().timeIntervalSince1970,
            progress: 0,
            last_update: Date().timeIntervalSince1970,
            milestones: [],
            blocked: false,
            failure_count: 0
        )
    }
    
    func updateProject(projectId: String, title: String?, description: String?, emotionalInvestment: String?) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        var body: [String: Any] = ["project_id": projectId]
        if let t = title { body["title"] = t }
        if let d = description { body["description"] = d }
        if let e = emotionalInvestment { body["emotional_investment"] = e }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func deleteProject(projectId: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func triggerSynthesis(projectId: String?) async throws -> SynthesisResponse {
        guard let url = URL(string: "\(baseURL)/projects/synthesis") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        var body: [String: Any] = [:]
        if let pid = projectId {
            body["project_id"] = pid
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SynthesisResponse.self, from: data)
    }
}

// MARK: - Preview

#Preview {
    ProjectDashboardView()
}
