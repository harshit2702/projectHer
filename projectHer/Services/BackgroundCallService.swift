//
//  BackgroundCallService.swift
//  projectHer
//
//  Enables voice/video calls that continue in background like phone calls
//  Uses CallKit for system-level call UI and AVAudioSession for background audio
//

import Foundation
import CallKit
import AVFoundation
import UIKit
import Combine

// MARK: - Background Call Service

@MainActor
class BackgroundCallService: NSObject, ObservableObject {
    static let shared = BackgroundCallService()
    
    // Call State
    @Published var isCallActive = false
    @Published var callDuration: TimeInterval = 0
    @Published var isMuted = false
    @Published var isSpeakerOn = true
    
    // CallKit Components
    private let callController = CXCallController()
    private var provider: CXProvider?
    private var currentCallUUID: UUID?
    
    // Audio Session
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    
    // Timer for call duration
    private var durationTimer: Timer?
    private var callStartTime: Date?
    
    // Callbacks
    var onCallStarted: (() -> Void)?
    var onCallEnded: (() -> Void)?
    var onMuteChanged: ((Bool) -> Void)?
    
    override init() {
        super.init()
        setupCallKit()
    }
    
    // MARK: - Setup
    
    private func setupCallKit() {
        // Use the initializer with localizedName (required for iOS 14+)
        let config = CXProviderConfiguration(localizedName: "Pandu")
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        
        // Use app icon if available
        if let iconImage = UIImage(named: "AppIcon") {
            config.iconTemplateImageData = iconImage.pngData()
        }
        
        // Audio settings
        config.ringtoneSound = nil // No ringtone for outgoing
        
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: .main)
    }
    
    // MARK: - Start Call
    
    /// Start a background call - allows voice to continue when app is backgrounded
    func startCall() async throws {
        guard !isCallActive else {
            print("📞 Call already active")
            return
        }
        
        // Configure audio session for VoIP
        try configureAudioSession()
        
        // Create new call UUID
        let uuid = UUID()
        currentCallUUID = uuid
        
        // Report outgoing call to CallKit
        let handle = CXHandle(type: .generic, value: "Pandu ❤️")
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = false
        
        let transaction = CXTransaction(action: startCallAction)
        
        do {
            try await callController.request(transaction)
            print("📞 CallKit: Call started")
            
            // Mark call as connected after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.provider?.reportOutgoingCall(with: uuid, connectedAt: Date())
                self.handleCallStarted()
            }
        } catch {
            print("📞 CallKit: Failed to start call: \(error)")
            throw error
        }
    }
    
    // MARK: - End Call
    
    /// End the current background call
    func endCall() async {
        guard let uuid = currentCallUUID else {
            print("📞 No active call to end")
            return
        }
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        do {
            try await callController.request(transaction)
            print("📞 CallKit: Call ended")
        } catch {
            print("📞 CallKit: Failed to end call: \(error)")
            // Force cleanup even if CallKit fails
            handleCallEnded()
        }
    }
    
    // MARK: - Mute Control
    
    /// Toggle mute state
    func toggleMute() async {
        guard let uuid = currentCallUUID else { return }
        
        let muteAction = CXSetMutedCallAction(call: uuid, muted: !isMuted)
        let transaction = CXTransaction(action: muteAction)
        
        do {
            try await callController.request(transaction)
        } catch {
            print("📞 CallKit: Failed to toggle mute: \(error)")
        }
    }
    
    /// Set mute state directly
    func setMuted(_ muted: Bool) async {
        guard let uuid = currentCallUUID else { return }
        
        let muteAction = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: muteAction)
        
        do {
            try await callController.request(transaction)
        } catch {
            print("📞 CallKit: Failed to set mute: \(error)")
        }
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("🔊 Audio session configured for VoIP")
    }
    
    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🔊 Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Internal Handlers
    
    private func handleCallStarted() {
        isCallActive = true
        callStartTime = Date()
        callDuration = 0
        
        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.callStartTime else { return }
                self.callDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        onCallStarted?()
        print("📞 Call active - can now use phone normally while voice continues")
    }
    
    private func handleCallEnded() {
        isCallActive = false
        currentCallUUID = nil
        callStartTime = nil
        callDuration = 0
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        deactivateAudioSession()
        onCallEnded?()
        print("📞 Call ended")
    }
    
    // MARK: - Utility
    
    var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - CXProviderDelegate

extension BackgroundCallService: CXProviderDelegate {
    
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            print("📞 CallKit provider reset")
            self.handleCallEnded()
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            print("📞 CallKit: CXStartCallAction")
            do {
                try self.configureAudioSession()
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            print("📞 CallKit: CXAnswerCallAction")
            do {
                try self.configureAudioSession()
                self.handleCallStarted()
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            print("📞 CallKit: CXEndCallAction")
            self.handleCallEnded()
            action.fulfill()
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task { @MainActor in
            print("📞 CallKit: CXSetMutedCallAction muted=\(action.isMuted)")
            self.isMuted = action.isMuted
            self.onMuteChanged?(action.isMuted)
            action.fulfill()
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        Task { @MainActor in
            print("📞 CallKit: CXSetHeldCallAction")
            // Could pause TTS/STT here if needed
            action.fulfill()
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in
            print("🔊 CallKit: Audio session activated")
        }
    }
    
    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor in
            print("🔊 CallKit: Audio session deactivated")
        }
    }
}

// MARK: - Picture-in-Picture Style Mini Call View

struct MiniCallView: View {
    @ObservedObject var callService = BackgroundCallService.shared
    let onTap: () -> Void
    let onEndCall: () -> Void
    
    var body: some View {
        if callService.isCallActive {
            HStack(spacing: 12) {
                // Avatar indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                    )
                
                Text("Pandu")
                    .font(.subheadline.bold())
                
                Text(callService.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Mute button
                Button(action: {
                    Task { await callService.toggleMute() }
                }) {
                    Image(systemName: callService.isMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(callService.isMuted ? .red : .primary)
                }
                
                // End call button
                Button(action: onEndCall) {
                    Image(systemName: "phone.down.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 4)
            .padding(.horizontal)
            .onTapGesture(perform: onTap)
        }
    }
}

import SwiftUI
