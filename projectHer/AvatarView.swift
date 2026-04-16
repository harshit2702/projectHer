import SpriteKit
import SwiftUI

struct AvatarView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase  // 🆕 For PiP on background
    @ObservedObject var tts: TTSManager
    @ObservedObject var stt: LiveSTT
    @Binding var voiceMode: Bool
    
    // 🆕 Background Call Service for call continuation
    @StateObject private var callService = BackgroundCallService.shared
    
    // 🆕 PiP Manager for picture-in-picture with animated mouth
    @StateObject private var pipManager = PiPManager.shared

    // Scene (Held as a State object)
    @State private var scene: AvatarScene = {
        let s = AvatarScene()
        s.size = CGSize(width: 450, height: 900)  // Logical size
        s.scaleMode = .aspectFill
        s.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return s
    }()

    // UI State
    @State private var showCustomize = false

    // Customization State
    @ObservedObject var wardrobe = WardrobeManager.shared
    @StateObject private var weatherKit = WeatherKitManager.shared
    @StateObject private var windManager = WindManager.shared

    // Voice Settings (for touch dialogue TTS)
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = ""
    @AppStorage("voicePitch") private var voicePitch: Double = 1.0
    @AppStorage("voiceRate") private var voiceRate: Double = 0.5

    var body: some View {
        ZStack {
            // Background Blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // 1. The Avatar (Fixed Frame for "Card" look)
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: 400, height: 700)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)

            // 2. Controls Overlay
            controlsOverlay
            
            // 3. 🆕 Background call indicator (when call is active but view minimized)
            if callService.isCallActive {
                VStack {
                    // Call duration badge at top
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Call Active • \(callService.formattedDuration)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showCustomize) {
            customizationSheet
        }
        .onAppear {
            // Initial sync
            syncLipSync()
            syncWardrobe()
            applyLocationEnvironment(weatherKit.environment)
            weatherKit.start()

            // Connect touch dialogue TTS callback
            scene.onSpeakDialogue = { [self] text, emotion in
                tts.speak(
                    text, voiceId: selectedVoiceId, pitchMultiplier: Float(voicePitch),
                    rate: Float(voiceRate))
            }
            
            // 🆕 Start background call on appear (makes call continue when minimized)
            Task {
                // Sync outfit BEFORE starting call so Live Activity shows correct avatar
                callService.currentOutfitId = wardrobe.currentOutfit.base.id
                try? await callService.startCall(isVideo: true)  // Video call
            }
        }
        .onChange(of: wardrobe.currentOutfit.base.id) { _, newOutfit in
            syncWardrobe()
            // Keep Live Activity in sync with outfit changes
            callService.currentOutfitId = newOutfit
        }
        .onChange(of: wardrobe.currentOutfit.accessories.map { $0.id }) { _, _ in
            syncWardrobe()
        }
        .onReceive(weatherKit.$environment) { environment in
            applyLocationEnvironment(environment)
        }
        .onChange(of: tts.isSpeaking) { _, speaking in
            if speaking {
                scene.startTalkNatural()
            } else {
                scene.stopTalk()
            }
            // 🆕 Sync TTS state to PiP for mouth animation
            pipManager.setTalking(speaking)
        }
        // 🆕 Auto-start PiP when app goes to background during call
        .onChange(of: scenePhase) { _, phase in
            // Must start PiP in inactive state (just before background)
            if phase == .inactive && callService.isCallActive {
                pipManager.setOutfit(wardrobe.currentOutfit.base.id)
                pipManager.startPiP()
            } else if phase == .active {
                pipManager.stopPiP()
            }
        }
        .onDisappear {
            weatherKit.stop()
            // Note: Don't end call on disappear - that's the point of background calls!
            // Call ends only when user explicitly ends it
        }
    }

    func applyLocationEnvironment(_ environment: WeatherEnvironment) {
        scene.weather.disableAll(lettingParticlesFinish: false)
        if !environment.effects.isEmpty {
            scene.weather.enable(environment.effects)
        }

        windManager.update(from: environment)
        scene.weather.setWind(dx: windManager.windDX)
        scene.lighting?.updateWeatherContext(
            cloudiness: environment.cloudiness,
            precipitation: environment.precipitationLevel
        )
        scene.lighting?.update(timeOfDay: environment.localHour)

        applyWindVariation(speed: windManager.currentWind.speed, isOutdoor: true)
    }

    /// Apply wind animation based on current outfit accessory (hat type)
    /// Wind variations A-F are based on hat, not speed:
    /// - A/B (Var1/2): No hat - normal hair
    /// - C (Var3): hat_1
    /// - D (Var4): winter_hat_motion_wind
    /// - E/F (Var5/6): winter_hat
    func applyWindVariation(speed: Float, isOutdoor: Bool) {
        // Indoor or no wind = stop animation
        if !isOutdoor || speed < 0.08 {
            scene.stopWind()
            return
        }

        scene.weather.setWind(dx: windManager.windDX)

        // Select wind variation based on current accessory (hat type)
        let currentAccessory = wardrobe.currentOutfit.accessories.first?.id ?? "none"

        switch currentAccessory {
        case let id where id.contains("winter_hat"):
            // Winter hat - use Var5 or Var6 based on stronger wind
            if speed > 0.5 {
                scene.startWindVar4()  // motion wind
            } else {
                scene.startWindVar5()  // static winter hat
            }
        case let id where id.contains("hat"):
            // Regular hat - use Var3
            scene.startWindVar3()
        default:
            // No hat - use Var1 (strong) or Var2 (lighter)
            if speed > 0.5 {
                scene.startWindVar1()
            } else {
                scene.startWindVar2()
            }
        }
    }

    var controlsOverlay: some View {
        VStack {
            // Top Controls
            HStack {
                Spacer()

                // Customize Button
                Button(action: { showCustomize = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
            }
            .padding()

            Spacer()

            // Status Indicators
            VStack(spacing: 10) {
                // Listening Indicator
                if voiceMode {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(stt.transcript.isEmpty ? "Listening..." : stt.transcript)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                }

                // Speaking Indicator
                if tts.isSpeaking {
                    Text("Speaking...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 20)

            // Bottom Controls (Call Style)
            HStack(spacing: 40) {
                // Mic Toggle
                Button(action: toggleMic) {
                    Image(systemName: voiceMode ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(voiceMode ? Color.white : Color.gray.opacity(0.5))
                        .foregroundColor(voiceMode ? .black : .white)
                        .clipShape(Circle())
                }
                
                // 🆕 Minimize button - keep call running in background with PiP
                Button(action: {
                    // Start PiP with current outfit, then dismiss
                    pipManager.setOutfit(wardrobe.currentOutfit.base.id)
                    pipManager.startPiP()
                    dismiss()
                }) {
                    Image(systemName: "rectangle.inset.bottomright.filled")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                // End Call - completely ends the background call
                Button(action: {
                    Task {
                        await callService.endCall()
                        dismiss()
                    }
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
    }

    var customizationSheet: some View {
        NavigationStack {
            Form {
                Section("Wardrobe") {
                    Picker(
                        "Outfit",
                        selection: Binding(
                            get: { wardrobe.currentOutfit.base.id },
                            set: { newId in
                                if let item = wardrobe.wardrobe.first(where: { $0.id == newId }) {
                                    wardrobe.changeOutfit(to: item)
                                }
                            }
                        )
                    ) {
                        ForEach(
                            wardrobe.wardrobe.filter {
                                $0.category == .dress || $0.category == .top
                                    || $0.category == .swimwear || $0.category == .outerwear
                            }, id: \.id
                        ) { item in
                            Text(item.name).tag(item.id)
                        }
                    }

                    // Simple Accessory Toggle (just showing one at a time for simplicity in UI, though system supports multiple)
                    Picker(
                        "Accessory",
                        selection: Binding(
                            get: { wardrobe.currentOutfit.accessories.first?.id ?? "none" },
                            set: { newId in
                                // Clear existing
                                if let current = wardrobe.currentOutfit.accessories.first {
                                    wardrobe.changeOutfit(to: current)  // Toggle off
                                }
                                if newId != "none",
                                    let item = wardrobe.wardrobe.first(where: { $0.id == newId })
                                {
                                    wardrobe.changeOutfit(to: item)
                                }
                            }
                        )
                    ) {
                        Text("None").tag("none")
                        ForEach(wardrobe.wardrobe.filter { $0.category == .accessories }, id: \.id)
                        { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                }

                Section("Environment") {
                    if weatherKit.isAuthorized {
                        LabeledContent("Location", value: weatherKit.environment.locationName)
                        LabeledContent("Condition", value: weatherKit.environment.conditionSummary)
                        LabeledContent("Local Time", value: formattedHour(weatherKit.environment.localHour))
                        LabeledContent("Wind", value: windManager.currentWind.name.capitalized)

                        Text("Background, lighting, particles, and wind sync automatically from wttr.in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enable location access to sync weather visuals automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Retry Location Access") {
                            weatherKit.start()
                        }
                    }
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCustomize = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    func syncWardrobe() {
        scene.updateOutfit(wardrobe.currentOutfit.base.modelAsset)
        // Reset accessories first if needed or handle multiple
        // For now, assuming single or handled by updateAccessory logic
        // AvatarScene updateAccessory logic was simple: if "scarf", show scarf.
        // We need to map modelAsset to logic if it's special, otherwise assume texture name.

        // Clear accessories first (conceptually)
        // Check what's active
        if let acc = wardrobe.currentOutfit.accessories.first {
            scene.updateAccessory(acc.modelAsset)
        } else {
            scene.updateAccessory("none")
        }
    }

    func syncLipSync() {
        if tts.isSpeaking {
            scene.startTalkNatural()
        } else {
            scene.stopTalk()
        }
    }

    func formattedHour(_ hour: CGFloat) -> String {
        let hourValue = max(0, min(23, Int(hour.rounded())))
        let period = hourValue >= 12 ? "PM" : "AM"
        let clockHour = hourValue % 12 == 0 ? 12 : hourValue % 12
        return "\(clockHour):00 \(period)"
    }

    func toggleMic() {
        if voiceMode {
            // Stop
            stt.stop()
            voiceMode = false
        } else {
            // Start
            voiceMode = true
            Task {
                try? await stt.requestPermissions()
                try? stt.start()
            }
        }
    }
}
