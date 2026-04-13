import SpriteKit
import SwiftUI

struct AvatarView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tts: TTSManager
    @ObservedObject var stt: LiveSTT
    @Binding var voiceMode: Bool
    
    // 🆕 Background Call Service for call continuation
    @StateObject private var callService = BackgroundCallService.shared

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
    @State private var isMinimized = false  // 🆕 For background mode

    // Customization State
    @ObservedObject var wardrobe = WardrobeManager.shared
    // Default is "auto" for new installs; existing users keep their stored preference.
    @AppStorage("avatarWeather") private var selectedWeather = "auto"
    @State private var windStrength: Double = 0.0

    // WeatherKit — drives weather and wind when "auto" is selected
    @StateObject private var weatherKit = WeatherKitManager.shared

    // Voice Settings (for touch dialogue TTS)
    @AppStorage("selectedVoiceId") private var selectedVoiceId: String = ""
    @AppStorage("voicePitch") private var voicePitch: Double = 1.0
    @AppStorage("voiceRate") private var voiceRate: Double = 0.5

    let weatherOptions: [(String, String)] = [
        ("Auto", "auto"),
        ("Clear", "clear"),
        ("Rain", "rain"),
        ("Snow", "snow"),
        ("Night", "night"),
    ]

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
            updateWeather(selectedWeather)

            // Start WeatherKit for location-based weather and wind
            weatherKit.start()

            // Connect touch dialogue TTS callback
            scene.onSpeakDialogue = { [self] text, emotion in
                tts.speak(
                    text, voiceId: selectedVoiceId, pitchMultiplier: Float(voicePitch),
                    rate: Float(voiceRate))
            }
            
            // 🆕 Start background call on appear (makes call continue when minimized)
            Task {
                try? await callService.startCall()
            }
        }
        .onChange(of: wardrobe.currentOutfit.base.id) { _, _ in
            syncWardrobe()
        }
        .onChange(of: wardrobe.currentOutfit.accessories.map { $0.id }) { _, _ in
            syncWardrobe()
        }
        .onChange(of: selectedWeather) { _, newValue in
            updateWeather(newValue)
        }
        .onChange(of: windStrength) { _, newValue in
            scene.weather.setWind(dx: CGFloat(newValue))
        }
        .onChange(of: tts.isSpeaking) { _, speaking in
            if speaking {
                scene.startTalkNatural()
            } else {
                scene.stopTalk()
            }
        }
        .onDisappear {
            weatherKit.stop()
            // Note: Don't end call on disappear - that's the point of background calls!
            // Call ends only when user explicitly ends it
        }
        .onReceive(weatherKit.$environment) { env in
            guard selectedWeather == "auto" else { return }
            applyWeatherEnvironment(env)
        }
    }

    // MARK: - Weather Environment Application

    /// Applies a WeatherEnvironment (from WeatherKit) to the avatar scene.
    func applyWeatherEnvironment(_ env: WeatherEnvironment) {
        scene.weather.disableAll()
        env.effects.forEach { scene.weather.enable($0) }

        windStrength = Double(env.windDX)
        scene.weather.setWind(dx: env.windDX)
        applyWindAnimation(dx: env.windDX)

        let hour: CGFloat = env.isDaytime ? 12 : 22
        scene.lighting?.update(timeOfDay: hour)
    }

    /// Selects the appropriate hair-wind animation based on wind strength and current accessory.
    func applyWindAnimation(dx: CGFloat) {
        let speed = Float(abs(dx) / 200.0)
        if speed < 0.1 {
            scene.stopWind()
            return
        }

        let currentAccessory = wardrobe.currentOutfit.accessories.first?.id ?? "none"
        switch currentAccessory {
        case let id where id.contains("winter_hat"):
            if speed > 0.5 { scene.startWindVar4() } else { scene.startWindVar5() }
        case let id where id.contains("hat"):
            scene.startWindVar3()
        default:
            if speed > 0.5 { scene.startWindVar1() } else { scene.startWindVar2() }
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
                
                // 🆕 Minimize button - keep call running in background
                Button(action: {
                    // Dismiss view but keep call active
                    dismiss()
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
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
                    Picker("Weather", selection: $selectedWeather) {
                        ForEach(weatherOptions, id: \.1) { item in
                            Text(item.0).tag(item.1)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading) {
                        Text("Wind Strength")
                        Slider(value: $windStrength, in: -200...200, step: 10)
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

    func updateWeather(_ type: String) {
        if type == "auto" {
            // Apply current WeatherKit state (also handled reactively via .onReceive)
            applyWeatherEnvironment(weatherKit.environment)
            return
        }

        // Manual override
        scene.weather.disableAll()
        scene.lighting?.update(timeOfDay: 12)  // Default day
        windStrength = 0
        scene.stopWind()

        switch type {
        case "rain":
            scene.weather.enable(.rain)
            scene.weather.enable(.fog)
        case "snow":
            scene.weather.enable(.snowBackground)
            scene.weather.enable(.snowForeground)
        case "night":
            scene.weather.setNightMode(true)
            scene.lighting?.update(timeOfDay: 22)
        default:  // clear
            break
        }
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
