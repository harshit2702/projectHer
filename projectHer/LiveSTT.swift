import Foundation
import Combine
import Speech
import AVFoundation
import UIKit

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
    
    // 🆕 Background task for network requests when app is backgrounded
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // 🆕 Track if we were interrupted
    private var wasInterrupted = false
    
    init(localeId: String = "en-IN") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        setupNotifications()
    }
    
    // 🆕 Setup audio interruption notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
        
        // Handle app going to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBackgrounding()
            }
        }
        
        // Handle app coming back to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppForegrounding()
            }
        }
    }
    
    // 🆕 Handle audio session interruption (phone call, Siri, etc.)
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🎤 Audio interrupted - pausing STT")
            wasInterrupted = isListening
            if isListening {
                // Don't call stop() to preserve state, just pause the engine
                audioEngine.pause()
            }
            
        case .ended:
            print("🎤 Audio interruption ended")
            if wasInterrupted {
                // Check if we should resume
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("🎤 Resuming STT after interruption")
                        try? audioEngine.start()
                    }
                }
            }
            wasInterrupted = false
            
        @unknown default:
            break
        }
    }
    
    // 🆕 Handle app going to background - start background task for pending sends
    private func handleAppBackgrounding() {
        if isListening && !transcript.isEmpty {
            print("🎤 App backgrounding with transcript - starting background task")
            startBackgroundTask()
            
            // Give a short grace period then finalize if still in background
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, self.isListening else { return }
                print("🎤 Background grace period ended - sending transcript")
                self.finishAndSend()
            }
        }
    }
    
    // 🆕 Handle app returning to foreground
    private func handleAppForegrounding() {
        endBackgroundTask()
        
        // Reconfigure audio session in case it was deactivated
        if isListening {
            try? configureAudioSession()
        }
    }
    
    private func startBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }
        
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "STTSend") { [weak self] in
            self?.endBackgroundTask()
        }
        print("🎤 Started background task: \(backgroundTaskId)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        print("🎤 Ended background task: \(backgroundTaskId)")
        backgroundTaskId = .invalid
    }
    
    func requestPermissions() async throws {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { throw NSError(domain: "STT", code: 1) }
        
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { throw NSError(domain: "STT", code: 2) }
    }
    
    // 🆕 Configure audio session for VoIP/background
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        print("🎤 Audio session configured for VoIP")
    }
    
    func start() throws {
        stop()
        
        // 🆕 Configure audio session before starting
        try configureAudioSession()
        
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
        
        print("🎤 STT started with background support")
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
        
        endBackgroundTask()
    }
    
    private func bumpSilenceTimer() {
        silenceTimer?.invalidate()
        let weakSelf = self
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceSeconds, repeats: false) { _ in
            Task { @MainActor in
                weakSelf.finishAndSend()
            }
        }
    }
    
    private func finishAndSend() {
        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        guard !final.isEmpty else { return }
        
        // 🆕 Start background task if in background to ensure network request completes
        if UIApplication.shared.applicationState == .background {
            startBackgroundTask()
        }
        
        onFinal?(final)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
