import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class LiveSTT: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    
    var silenceSeconds: TimeInterval = 1.0
    var onFinal: ((String) -> Void)?
    
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    
    init(localeId: String = "en-IN") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
    }
    
    func requestPermissions() async throws {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { throw NSError(domain: "STT", code: 1) }
        
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { throw NSError(domain: "STT", code: 2) }
    }
    
    func start() throws {
        stop()
        
        transcript = ""
        isListening = true
        
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
        
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                self.transcript = result.bestTranscription.formattedString
                self.bumpSilenceTimer()
                if result.isFinal { self.finishAndSend() }
            }
            
            if error != nil { self.stop() }
        }
    }
    
    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        isListening = false
        task?.cancel()
        task = nil
        
        request?.endAudio()
        request = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func bumpSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishAndSend()
            }
        }
    }
    
    private func finishAndSend() {
        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        guard !final.isEmpty else { return }
        onFinal?(final)
    }
}
