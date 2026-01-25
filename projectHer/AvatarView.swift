import SwiftUI
import SpriteKit

struct AvatarView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tts: TTSManager
    
    // Scene (Held as a State object)
    @State private var scene: AvatarScene = {
        let s = AvatarScene()
        s.size = CGSize(width: 535, height: 940) // Logical size
        s.scaleMode = .aspectFill
        s.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return s
    }()
    
    // UI State
    @State private var isMuted = false
    @State private var showCustomize = false
    
    // Customization State
    @ObservedObject var wardrobe = WardrobeManager.shared
    @AppStorage("avatarWeather") private var selectedWeather = "clear"
    @State private var windStrength: Double = 0.0
    
    let weatherOptions: [(String, String)] = [
        ("Clear", "clear"),
        ("Rain", "rain"),
        ("Snow", "snow"),
        ("Night", "night")
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
        }
        .sheet(isPresented: $showCustomize) {
            customizationSheet
        }
        .onAppear {
            // Initial sync
            syncLipSync()
            syncWardrobe()
            updateWeather(selectedWeather)
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
            }
            else {
                scene.stopTalk()
            }
        }
    }

    var controlsOverlay: some View {
        VStack {
            HStack {
                // Customize Button
                Button(action: { showCustomize = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Mute/Unmute
                Button(action: { isMuted.toggle() }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                
                // Close
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
            }
            .padding()
            
            Spacer()
            
            // Caption Area
            if tts.isSpeaking {
                Text("Speaking...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(.bottom, 50)
                    .transition(.opacity)
            }
        }
    }

    var customizationSheet: some View {
        NavigationStack {
            Form {
                Section("Wardrobe") {
                    Picker("Outfit", selection: Binding(
                        get: { wardrobe.currentOutfit.base.id },
                        set: { newId in
                            if let item = wardrobe.wardrobe.first(where: { $0.id == newId }) {
                                wardrobe.changeOutfit(to: item)
                            }
                        }
                    )) {
                        ForEach(wardrobe.wardrobe.filter { $0.category == .dress || $0.category == .top || $0.category == .swimwear || $0.category == .outerwear }, id: \.id) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    
                    // Simple Accessory Toggle (just showing one at a time for simplicity in UI, though system supports multiple)
                    Picker("Accessory", selection: Binding(
                        get: { wardrobe.currentOutfit.accessories.first?.id ?? "none" },
                        set: { newId in
                            // Clear existing
                            if let current = wardrobe.currentOutfit.accessories.first {
                                wardrobe.changeOutfit(to: current) // Toggle off
                            }
                            if newId != "none", let item = wardrobe.wardrobe.first(where: { $0.id == newId }) {
                                wardrobe.changeOutfit(to: item)
                            }
                        }
                    )) {
                        Text("None").tag("none")
                        ForEach(wardrobe.wardrobe.filter { $0.category == .accessories }, id: \.id) { item in
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
        // Reset
        scene.weather.disableAll()
        scene.lighting?.update(timeOfDay: 12) // Default day
        
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
        default: // clear
            break
        }
    }
}
