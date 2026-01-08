import Foundation
import Combine
import AVFoundation

@MainActor
final class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    
    private let synth = AVSpeechSynthesizer()
    var onFinish: (() -> Void)?
    
    override init() {
        super.init()
        synth.delegate = self
        loadVoices()
        configureAudioSession(useSpeaker: true) // Default to speaker
    }
    
    func loadVoices() {
        // Filter for English voices to keep the list manageable, or remove filter for all.
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }
    }
    
    func configureAudioSession(useSpeaker: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetoothA2DP, .allowBluetoothHFP])
            if useSpeaker {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
            try session.setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    func speak(_ text: String, voiceId: String? = nil, pitchMultiplier: Float = 1.0, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        synth.stopSpeaking(at: .immediate)
        
        let utt = AVSpeechUtterance(string: cleaned)
        
        // Use selected voice or fallback to default
        if let voiceId = voiceId, let voice = availableVoices.first(where: { $0.identifier == voiceId }) {
            utt.voice = voice
        } else {
            utt.voice = AVSpeechSynthesisVoice(language: "en-IN")
        }
        
        utt.pitchMultiplier = pitchMultiplier
        utt.rate = rate
        
        isSpeaking = true
        synth.speak(utt)
    }
    
    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish?()
        }
    }
}
