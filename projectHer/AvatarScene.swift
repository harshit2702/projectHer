import SpriteKit
import UIKit
import Combine

enum GestureIntensity: Int {
    case gentle = 1, moderate, intense
}

class AvatarScene: SKScene, ObservableObject {
    
    // MARK: - Node References
    var body: SKSpriteNode!
    var hairFront: SKSpriteNode!
    var hairBase: SKSpriteNode!
    var hairOverlay: SKSpriteNode!
    var eyes: SKSpriteNode!
    var mouth: SKSpriteNode!
    var brows: SKSpriteNode!
    var scarfFront: SKSpriteNode!
    var scarfBack: SKSpriteNode!
    
    // Debug Masks
    var earMask: SKSpriteNode!
    var neckMask: SKSpriteNode!
    var noseMask: SKSpriteNode!
    var cheeksMask: SKSpriteNode!
    var shoulderMask: SKSpriteNode!
    
    // Debug Highlight (Internal)
    var mouthHighlight: SKShapeNode!
    
    // --- Interaction ---
    var onGestureDetected: ((String, String) -> Void)?
    
    /// Callback to trigger TTS from touch dialogues
    /// Parameters: (text, emotion) - AvatarView connects this to TTSManager
    var onSpeakDialogue: ((String, String) -> Void)?
    
    // --- Touch State (Internal for Extensions) ---
    var activeTouch: UITouch?
    var touchStartLocation: CGPoint = .zero
    var touchStartTime: TimeInterval = 0
    var detectedPart: String?
    
    // Pinch State (Internal)
    var pinchStartDistance: CGFloat = 0
    var isPinching = false
    
    // Configuration (Internal)
    let slideThreshold: CGFloat = 20.0
    let longPressTime: TimeInterval = 0.5
    let pinchThreshold: CGFloat = 10.0
    
    // --- State (Observable) ---
    @Published var isBreathingState = true
    @Published var activeTalk: String? = nil
    @Published var activePreset: String? = nil
    @Published var activeWind: String? = nil

    // --- Haptics ---
    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    let notificationGenerator = UINotificationFeedbackGenerator()

    // --- Weather ---
    lazy var weather = WeatherController(scene: self)
    
    // --- Lighting ---
    var lighting: LightingController?

    // --- Internal State ---
    var isHeadTilting = true
    var isSwaying = true
    var isBlinking = true
    
    // Talking State (Internal)
    var isTalking = false
    var lastPhoneme = ""
    var phonemeRepeatCount = 0
    
    // Shared Statics
    static let windKey = "wind"
    static var _baseHairName: String = "none"
    
    func classifyLongPress(duration: TimeInterval) -> GestureIntensity {
        switch duration {
        case ..<1.0: return .gentle
        case ..<2.0: return .moderate
        default: return .intense
        }
    }

    func classifyPinch(delta: CGFloat) -> GestureIntensity {
        switch delta {
        case ..<20: return .gentle
        case ..<40: return .moderate
        default: return .intense
        }
    }

    override func didMove(to view: SKView) {
        backgroundColor = .gray
        setupPuppet()
        setupDebugHighlights()
        configureLighting()
        
        // Start all "alive" motions by default
        setBreathing(enabled: true)
        setHeadTilt(enabled: true)
        setSwaying(enabled: true)
        setBlinking(enabled: true)
        
        // Enable multi-touch for pinch detection
        view.isMultipleTouchEnabled = true
    }
    
    func setMasksVisible(_ visible: Bool) {
        let masks = [earMask, neckMask, noseMask, cheeksMask, shoulderMask]
        for mask in masks {
            mask?.alpha = visible ? 0.5 : 0.0
        }
    }
    
    func setupPuppet() {
        let currentOutfit = WardrobeManager.shared.currentOutfit
        
        // 1. Body Anchor
        body = SKSpriteNode(imageNamed: currentOutfit.base.modelAsset)
        body.position = CGPoint(x: 0, y: 0)
        body.setScale(0.35)
        body.zPosition = 10
        addChild(body)
        
        // 2. Back Layers
        scarfBack = SKSpriteNode(imageNamed: "scarf_back")
        scarfBack.position = CGPoint(x: 0, y: 0)
        scarfBack.zPosition = -2
        scarfBack.isHidden = !currentOutfit.accessories.contains(where: { $0.id == "scarf" })
        body.addChild(scarfBack)
        
        // 3. Face Layers
        eyes = SKSpriteNode(imageNamed: "eye_open")
        eyes.position = CGPoint(x: 0, y: 0)
        eyes.zPosition = 20
        body.addChild(eyes)
        
        brows = SKSpriteNode(imageNamed: "brow_neutral")
        brows.position = CGPoint(x: 0, y: 0)
        brows.zPosition = 21
        body.addChild(brows)
        
        mouth = SKSpriteNode(imageNamed: "mouth_neutral")
        mouth.position = CGPoint(x: -10, y: 0) // Default offset
        mouth.zPosition = 20
        body.addChild(mouth)
        
        // 4. Front Accessories
        scarfFront = SKSpriteNode(imageNamed: "scarf_front")
        scarfFront.position = CGPoint(x: 0, y: 0)
        scarfFront.zPosition = 30
        
        // Initial Accessory Visibility/Texture logic
        if currentOutfit.accessories.contains(where: { $0.id == "pendant" }) {
            scarfFront.texture = SKTexture(imageNamed: "pendant")
            scarfFront.position = CGPoint(x: 0, y: -50)
            scarfFront.isHidden = false
        } else if currentOutfit.accessories.contains(where: { $0.id == "scarf" }) {
            scarfFront.texture = SKTexture(imageNamed: "scarf_front")
            scarfFront.position = CGPoint(x: 0, y: 0)
            scarfFront.isHidden = false
        } else {
            scarfFront.isHidden = true
        }
        
        body.addChild(scarfFront)
        
        // 5. Hair (Base + Overlay)
        hairBase = SKSpriteNode(imageNamed: "hair")
        hairBase.position = CGPoint(x: 0, y: -5)
        hairBase.zPosition = 29          // Default behind overlay
        hairBase.isHidden = false        // Default visible (so avatar has hair)
        body.addChild(hairBase)

        hairOverlay = SKSpriteNode(imageNamed: "hair")
        hairOverlay.position = CGPoint(x: 0, y: -5)
        hairOverlay.zPosition = 31       // Above face
        hairOverlay.isHidden = true      // Default hidden (only for wind)
        body.addChild(hairOverlay)

        // Compatibility alias
        hairFront = hairOverlay
        
        // --- Debug Masks (Check Alignment) ---
        earMask = SKSpriteNode(imageNamed: "ear_mask")
        earMask.position = CGPoint(x: 0, y: 0)
        earMask.zPosition = 50
        earMask.alpha = 0.0 // Transparent
        body.addChild(earMask)
        
        neckMask = SKSpriteNode(imageNamed: "neck_mask")
        neckMask.position = CGPoint(x: 0, y: 0)
        neckMask.zPosition = 50
        neckMask.alpha = 0.0
        body.addChild(neckMask)
        
        noseMask = SKSpriteNode(imageNamed: "nose_mask")
        noseMask.position = CGPoint(x: 0, y: 0)
        noseMask.zPosition = 50
        noseMask.alpha = 0.0
        body.addChild(noseMask)
        
        cheeksMask = SKSpriteNode(imageNamed: "cheeks_mask")
        cheeksMask.position = CGPoint(x: 0, y: 0)
        cheeksMask.zPosition = 50
        cheeksMask.alpha = 0.0
        body.addChild(cheeksMask)
        
        shoulderMask = SKSpriteNode(imageNamed: "schoulder_mask")
        shoulderMask.position = CGPoint(x: 0, y: 0)
        shoulderMask.zPosition = 50
        shoulderMask.alpha = 0.0
        body.addChild(shoulderMask)
    }
    
    // MARK: - Debug Highlight
    func setupDebugHighlights() {
        // 1. Mouth Box
        let mouthSize = CGSize(width: 275, height: 150)
        let mouthOffset = CGPoint(x: 40, y: 75)
        
        mouthHighlight = SKShapeNode(rectOf: mouthSize)
        mouthHighlight.position = mouthOffset
        mouthHighlight.fillColor = .red
        mouthHighlight.strokeColor = .clear
        mouthHighlight.alpha = 0.001
        mouthHighlight.zPosition = 100
        body.addChild(mouthHighlight)
    }
    
    func setMouthDebugVisible(_ visible: Bool) {
        mouthHighlight?.alpha = visible ? 0.5 : 0.01
    }
    
    // MARK: - Haptics
    func triggerHaptic(type: String) {
        switch type {
        case "success":
            notificationGenerator.notificationOccurred(.success)
        case "warning":
            notificationGenerator.notificationOccurred(.warning)
        case "error":
            notificationGenerator.notificationOccurred(.error)
        case "light":
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        case "medium":
            impactGenerator.impactOccurred()
        case "heavy":
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
        default:
            break
        }
    }

    // MARK: - Customization
    func updateOutfit(_ outfit: String) {
        guard body != nil else { return }
        body.texture = SKTexture(imageNamed: outfit)
    }

    func updateAccessory(_ accessory: String) {
        guard body != nil else { return }
        
        if accessory == "scarf" {
            scarfFront.isHidden = false
            scarfBack.isHidden = false
            scarfFront.texture = SKTexture(imageNamed: "scarf_front")
            scarfBack.texture = SKTexture(imageNamed: "scarf_back")
            scarfFront.setScale(1.0)
            scarfFront.position = CGPoint(x: 0, y: 0)
        } else if accessory == "pendant" {
            scarfFront.isHidden = false
            scarfBack.isHidden = true
            scarfFront.texture = SKTexture(imageNamed: "pendant")
            scarfFront.position = CGPoint(x: 0, y: -50)
            scarfFront.setScale(1.0)
        } else {
            scarfFront.isHidden = true
            scarfBack.isHidden = true
        }
    }

    func updateAvatar(outfit: String, accessory: String) {
        updateOutfit(outfit)
        updateAccessory(accessory)
    }
}
