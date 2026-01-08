import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = ""
    @AppStorage("useSpeaker") private var useSpeaker: Bool = true
    @AppStorage("silenceDuration") private var silenceDuration: Double = 1.5
    @AppStorage("voicePitch") private var voicePitch: Double = 1.0
    @AppStorage("voiceRate") private var voiceRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    
    @AppStorage("showEmotionalState") private var showEmotionalState: Bool = true
    
    @ObservedObject var tts: TTSManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
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
    }
}