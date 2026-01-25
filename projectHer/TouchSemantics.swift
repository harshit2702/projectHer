// TouchSemantics.swift - Emotional mapping for supported physical interactions

import Foundation
import CoreGraphics

/// Represents the physical body parts with active mask detection
enum TouchPart: String, Codable {
    case mouth = "Mouth"
    case nose = "Nose"
    case cheeks = "Cheeks"
    case ears = "Ears"
    case neck = "Neck"
    case shoulders = "Shoulders"
    case hair = "Hair"
}

/// Represents the gestures supported by the AvatarScene detection logic
enum GestureType: String, Codable {
    case tap = "Tap"
    case longPress = "Long Press"
    case pinch = "Pinch"
    case slide = "Slide"
    case pull = "Pull" // Specialized slide for Hair
}

struct PhysicalInteraction {
    let part: TouchPart
    let gesture: GestureType
    let intensity: Int // 1: gentle, 2: moderate, 3: intense
    
    var emotionalMeaning: String {
        switch (part, gesture) {
        case (.cheeks, .slide): return "affectionate_nuzzle"
        case (.cheeks, .pinch): return "playful_tease_ouch"
        case (.shoulders, .tap): return "attention_seeking"
        case (.mouth, .tap): return "intimate_finger_kiss"
        case (.ears, .slide): return "mischievous_ear_stroke"
        case (.ears, .tap): return "ticklish_play"
        case (.nose, .tap): return "cute_boop"
        case (.nose, .longPress): return "playful_annoyance"
        case (.neck, .slide): return "sensual_shy_touch"
        case (.hair, .pull): return "playful_hair_tugging"
        case (.hair, .tap): return "gentle_pat"
        default: return "physical_touch"
        }
    }
    
    var contextDescription: String {
        switch (part, gesture) {
        case (.cheeks, .slide):
            return "User gently caressed your cheek with a nuzzle-like slide."
        case (.cheeks, .pinch):
            return "User gave your cheek a playful pinch."
        case (.shoulders, .tap):
            return "User tapped your shoulder to get your attention."
        case (.mouth, .tap):
            return "User placed a finger on your lips or gave you a finger-kiss."
        case (.ears, .slide), (.ears, .tap):
            return "User is playing with or tickling your ears."
        case (.nose, .tap):
            return "User booped your nose!"
        case (.nose, .longPress):
            return "User is holding their finger on your nose playfully."
        case (.neck, .slide):
            return "User is softly stroking your neck, making you feel a bit shy."
        case (.hair, .pull):
            return "User is playfully pulling or tugging on your hair."
        case (.hair, .tap):
            return "User gave your hair a gentle pat."
        default:
            return "User touched your \(part.rawValue) with a \(gesture.rawValue)."
        }
    }
    
    func toModelContext() -> String {
        return """
        [PHYSICAL INTERACTION]
        Part: \(part.rawValue)
        Gesture: \(gesture.rawValue)
        Meaning: \(emotionalMeaning)
        Intensity: \(intensity == 3 ? "Intense" : intensity == 2 ? "Moderate" : "Gentle")
        Description: \(contextDescription)
        """
    }
}