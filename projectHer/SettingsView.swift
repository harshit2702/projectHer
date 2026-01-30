import SwiftUI
import AVFoundation
import ActivityKit

struct SettingsView: View {
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = ""
    @AppStorage("useSpeaker") private var useSpeaker: Bool = true
    @AppStorage("silenceDuration") private var silenceDuration: Double = 1.5
    @AppStorage("voicePitch") private var voicePitch: Double = 1.0
    @AppStorage("voiceRate") private var voiceRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    
    @AppStorage("showEmotionalState") private var showEmotionalState: Bool = true
    
    @ObservedObject var tts: TTSManager
    @Environment(\.dismiss) var dismiss
    
    // Feature #5: Live Activity Restart State
    @State private var isRestartingActivity = false
    @State private var activityRestartMessage: String?
    
    // Feature #2: Project Dashboard State
    @State private var showingProjectDashboard = false
    
    var body: some View {
        NavigationView {
            Form {
                // 🆕 Feature #2: Projects Section
                Section(header: Text("Pandu's Projects")) {
                    Button(action: { showingProjectDashboard = true }) {
                        HStack {
                            Image(systemName: "folder.badge.gearshape")
                                .foregroundColor(.purple)
                            Text("Project Dashboard")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // 🆕 Feature #5: Live Activity Section
                Section(header: Text("Live Activity")) {
                    Button(action: { Task { await restartLiveActivity() } }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .foregroundColor(.blue)
                            Text("Restart Presence")
                            Spacer()
                            if isRestartingActivity {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRestartingActivity)
                    
                    if let message = activityRestartMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("✅") ? .green : .orange)
                    }
                }
                
                Section(header: Text("Interaction Flow")) {
                    VStack(alignment: .leading) {
                        Text("Silence Detection: \(silenceDuration, specifier: "%.1f")s")
                        Slider(value: $silenceDuration, in: 0.5...5.0, step: 0.1)
                    }
                    .help("How long to wait after you stop speaking before sending.")
                    
                    Toggle("Show Emotional State", isOn: $showEmotionalState)
                }
                
                Section(header: Text("Audio Output")) {
                    Toggle("Use Speaker", isOn: $useSpeaker)
                        .onChange(of: useSpeaker) { _, newValue in
                            tts.configureAudioSession(useSpeaker: newValue)
                        }
                }
                
                Section(header: Text("Voice Settings")) {
                    VStack(alignment: .leading) {
                        Text("Pitch: \(voicePitch, specifier: "%.2f")")
                        Slider(value: $voicePitch, in: 0.5...2.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Speed: \(voiceRate, specifier: "%.2f")")
                        Slider(value: $voiceRate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate), step: 0.05)
                    }
                    
                    Button("Reset Voice Settings") {
                        voicePitch = 1.0
                        voiceRate = Double(AVSpeechUtteranceDefaultSpeechRate)
                    }
                }
                
                Section(header: Text("Available Voices")) {
                    List(tts.availableVoices, id: \.identifier) { voice in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(voice.name)
                                    .font(.headline)
                                HStack {
                                    Text(voice.language)
                                    if voice.quality == .enhanced {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption2)
                                    }
                                    if voice.quality == .premium {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption2)
                                    }
                                    if voice.gender == .female {
                                        Image(systemName: "person.crop.circle.badge.moon") // rough proxy for female
                                            .foregroundColor(.pink)
                                            .font(.caption2)
                                    } else if voice.gender == .male {
                                         Image(systemName: "person.crop.circle")
                                            .foregroundColor(.blue)
                                            .font(.caption2)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if voice.identifier == selectedVoiceId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVoiceId = voice.identifier
                            // Preview with current settings
                            tts.speak("Hello, I am \(voice.name).", 
                                      voiceId: voice.identifier,
                                      pitchMultiplier: Float(voicePitch),
                                      rate: Float(voiceRate))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .onAppear {
            tts.configureAudioSession(useSpeaker: useSpeaker)
        }
        .sheet(isPresented: $showingProjectDashboard) {
            ProjectDashboardView()
        }
    }
    
    // MARK: - Feature #5: Restart Live Activity
    
    private func restartLiveActivity() async {
        isRestartingActivity = true
        activityRestartMessage = nil
        
        do {
            let response = try await LiveActivityAPIService.shared.restartActivity()
            
            await MainActor.run {
                if response.status == "ready", let activityType = response.activityType {
                    // Start the appropriate Live Activity
                    if #available(iOS 16.1, *) {
                        switch activityType {
                        case "transit":
                            if let data = response.data {
                                PanduLiveActivityManager.shared.startTransitActivity(
                                    origin: data["origin"]?.value as? String ?? "",
                                    originDisplay: data["origin_display"]?.value as? String ?? "",
                                    destination: data["destination"]?.value as? String ?? "",
                                    destinationDisplay: data["destination_display"]?.value as? String ?? "",
                                    etaTimestamp: data["eta_timestamp"]?.value as? TimeInterval ?? 0
                                )
                                activityRestartMessage = "✅ Transit activity started!"
                            }
                        case "sleep":
                            if let data = response.data {
                                PanduLiveActivityManager.shared.startSleepActivity(
                                    wakeTimestamp: data["wake_timestamp"]?.value as? TimeInterval ?? 0,
                                    wakeTimeDisplay: data["wake_time_display"]?.value as? String ?? "7:00 AM",
                                    initialPhase: data["sleep_phase"]?.value as? String ?? "sleeping"
                                )
                                activityRestartMessage = "✅ Sleep activity started!"
                            }
                        case "presence":
                            // For presence, we might not have a dedicated activity type yet
                            // But we acknowledge the state
                            activityRestartMessage = "✅ Presence synced (no active transit/sleep)"
                        default:
                            activityRestartMessage = "⚠️ No activity to show right now"
                        }
                    } else {
                        activityRestartMessage = "⚠️ Live Activities require iOS 16.1+"
                    }
                } else {
                    activityRestartMessage = "⚠️ \(response.error ?? "Unknown error")"
                }
                isRestartingActivity = false
            }
        } catch {
            await MainActor.run {
                activityRestartMessage = "❌ Failed: \(error.localizedDescription)"
                isRestartingActivity = false
            }
        }
    }
}

// MARK: - Live Activity API Service

struct LiveActivityRestartResponse: Codable {
    let status: String
    let activityType: String?
    let shouldShow: Bool?
    let data: [String: AnyCodable]?
    let timestamp: TimeInterval?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case activityType = "activity_type"
        case shouldShow = "should_show"
        case data
        case timestamp
        case error
    }
}

// Helper for decoding dynamic JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        }
    }
}

class LiveActivityAPIService {
    static let shared = LiveActivityAPIService()
    
    private let baseURL = AppConfig.serverURL
    private let apiKey = AppConfig.apiKey
    
    private init() {}
    
    func restartActivity() async throws -> LiveActivityRestartResponse {
        guard let url = URL(string: "\(baseURL)/live-activity/restart") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse the response manually due to dynamic data field
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return LiveActivityRestartResponse(
                status: json["status"] as? String ?? "error",
                activityType: json["activity_type"] as? String,
                shouldShow: json["should_show"] as? Bool,
                data: (json["data"] as? [String: Any])?.mapValues { AnyCodable($0) },
                timestamp: json["timestamp"] as? TimeInterval,
                error: json["error"] as? String
            )
        }
        
        throw URLError(.cannotParseResponse)
    }
}