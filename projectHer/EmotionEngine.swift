import Foundation

// MARK: - Types
enum EmotionalZone: String {
    case ecstatic     // High V, High A
    case playful      // Mod V, High A
    case calm         // Mod V, Low A
    case affectionate // High V, Low A
    case annoyed      // Low V, High A
    case furious      // Very Low V, Very High A
    case cold         // Low V, Low A
    case depressed    // Very Low V, Low A
    case neutral      // Center
}

class EmotionEngine {
    
    // Singleton for global access
    static let shared = EmotionEngine()
    
    // MARK: - State Variables
    // Valence: -1.0 (Hate) to 1.0 (Love)
    private var valence: Float = 0.5
    
    // Arousal: 0.0 (Sleepy) to 1.0 (Manic)
    private var arousal: Float = 0.5
    
    // Patience: 0.0 (Snap) to 1.0 (Saint)
    private var patience: Float = 1.0
    
    // Metadata
    private var lastInteraction: Date = Date()
    private var consecutiveFastMessages: Int = 0
    private var conflictTrigger: String? = nil // Why is she mad?
    
    private init() {
        loadState() // Auto-load on init
        wakeUp()    // Calculate decay immediately on load
    }
    
    // MARK: - 1. The Wake Up Logic (Persistence & Decay)
    /// Call this inside sceneWillEnterForeground or on init
    func wakeUp() {
        let now = Date()
        let hoursPassed = Float(now.timeIntervalSince(lastInteraction) / 3600.0)
        
        // A. Reset Arousal (Energy always normalizes to 0.5)
        // Move 50% closer to neutral per hour
        arousal = lerp(start: arousal, end: 0.5, t: 0.5 * hoursPassed)
        
        // B. Decay Valence (The "Grudge" Logic)
        if valence < 0 {
            // Negative emotions stick (Asymmetric Decay)
            // Recover only 10% per hour
            valence = lerp(start: valence, end: 0.0, t: 0.1 * hoursPassed)
        } else {
            // Positive emotions fade faster
            // The "thrill" fades 30% per hour
            valence = lerp(start: valence, end: 0.0, t: 0.3 * hoursPassed)
        }
        
        // C. Refill Patience tank completely if away > 1 hour
        if hoursPassed > 1.0 {
            patience = 1.0
            consecutiveFastMessages = 0
        }
        
        // D. Circadian Impact (Are we waking her up at 3 AM?)
        let hour = Calendar.current.component(.hour, from: now)
        if (hour >= 2 && hour <= 5) && hoursPassed > 4.0 {
            // Woken from deep sleep
            arousal = 0.2 // Groggy
            valence -= 0.4 // Annoyed
        }
        
        saveState()
    }
    
    // MARK: - 2. Interaction Processor
    /// Call this every time the User hits "Send"
    func processUserMessage(_ text: String) {
        let now = Date()
        let secondsSinceLast = now.timeIntervalSince(lastInteraction)
        
        // A. Spam Detection (Velocity)
        if secondsSinceLast < 5.0 {
            consecutiveFastMessages += 1
            // Penalty: Drop patience
            patience -= 0.15
        } else {
            // Recovery: If slow response, regain patience
            consecutiveFastMessages = 0
            patience = min(1.0, patience + 0.1)
        }
        
        // B. Basic Engagement Reward
        // If not spamming, talking makes her slightly happier (Engagement)
        if patience > 0.4 {
            valence = min(1.0, valence + 0.05)
            arousal = min(1.0, arousal + 0.05)
        }
        
        // C. (Optional) Simple Keyword Analysis for huge conflicts
        // Real analysis should happen in LLM, but we can do quick checks here
        if text.lowercased().contains("hate you") {
            valence -= 0.5
            conflictTrigger = "User said they hate her"
        }
        
        lastInteraction = now
        saveState()
    }
    
    // MARK: - 3. Output Accessors
    
    func getCurrentMood() -> String {
        return determineZone().rawValue.uppercased()
    }
    
    func getCurrentEnergy() -> Float {
        return arousal
    }
    
    func getToneInstruction() -> String {
        // A. Check Patience Override
        if patience < 0.2 {
            return "You are overwhelmed. The user is spamming. Be curt. Tell them to slow down."
        }
        
        // B. Determine Zone
        let mood = determineZone()
        var instructions = ""
        
        switch mood {
        case .ecstatic: instructions = "Energy is high! Use exclamation marks! Be manic and fun."
        case .playful:  instructions = "Be teasing and witty. Use emojis. Flirt a little."
        case .calm:     instructions = "Be peaceful, thoughtful, and verbose. Speak softly."
        case .annoyed:  instructions = "You are irritated. Give short answers. Be passive-aggressive."
        case .furious:  instructions = "You are angry. Do not be helpful. Confront the user."
        case .cold:     instructions = "Be distant. One word answers. 'Fine', 'Okay', 'Whatever'."
        case .depressed:instructions = "You are sad. Sound hopeless. Low energy."
        default:        instructions = "Be pleasant and helpful."
        }
        
        // C. Context Injection (The Memory)
        if let trigger = conflictTrigger, valence < -0.3 {
            instructions += " You are specifically upset because: \(trigger)."
        }
        
        return instructions
    }
    
    // MARK: - Legacy / Debugging
    /// Inject this string into your System Prompt
    func getMoodPrompt() -> String {
        return """
        [CURRENT EMOTIONAL STATE]
        - Mood: \(getCurrentMood())
        - Energy: \(String(format: "%.2f", arousal))
        - Tone Instruction: \(getToneInstruction())
        """
    }
    
    // MARK: - Debugging / UI Accessors
    func getDebugInfo() -> String {
        let mood = determineZone()
        return """
        Valence: \(String(format: "%.2f", valence))
        Arousal: \(String(format: "%.2f", arousal))
        Patience: \(String(format: "%.2f", patience))
        Zone: \(mood.rawValue.capitalized)
        """
    }
    
    // MARK: - Helper Logic
    
    private func determineZone() -> EmotionalZone {
        if valence >= 0.5 && arousal >= 0.6 { return .ecstatic }
        if valence >= 0.0 && arousal >= 0.5 { return .playful }
        if valence >= 0.5 && arousal < 0.5 { return .affectionate }
        if valence >= 0.0 && arousal < 0.5 { return .calm }
        
        if valence < -0.6 && arousal > 0.6 { return .furious }
        if valence < 0.0 && arousal > 0.5 { return .annoyed }
        if valence < -0.5 && arousal < 0.5 { return .depressed }
        if valence < 0.0 && arousal < 0.5 { return .cold }
        
        return .neutral
    }
    
    private func lerp(start: Float, end: Float, t: Float) -> Float {
        return start + (end - start) * min(max(t, 0), 1)
    }
    
    // MARK: - Persistence
    private func saveState() {
        let defaults = UserDefaults.standard
        defaults.set(valence, forKey: "her_valence")
        defaults.set(arousal, forKey: "her_arousal")
        defaults.set(patience, forKey: "her_patience")
        defaults.set(lastInteraction, forKey: "her_lastTime")
        if let trigger = conflictTrigger {
            defaults.set(trigger, forKey: "her_trigger")
        }
    }
    
    private func loadState() {
        let defaults = UserDefaults.standard
        // Check if key exists, else default is already set
        if defaults.object(forKey: "her_valence") != nil {
            valence = defaults.float(forKey: "her_valence")
            arousal = defaults.float(forKey: "her_arousal")
            patience = defaults.float(forKey: "her_patience")
            lastInteraction = defaults.object(forKey: "her_lastTime") as? Date ?? Date()
            conflictTrigger = defaults.string(forKey: "her_trigger")
        }
    }
}
