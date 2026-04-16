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

enum TouchReactionOutcome: String {
    case positive
    case neutral
    case negative
}

enum TouchDialogueMode: String {
    case silent
    case speak
}

struct LocalTouchReaction {
    let reactionId: String
    let outcome: TouchReactionOutcome
    let dialogue: String?
    let dialogueMode: TouchDialogueMode
    let dialogueEmotion: String
    let spawnHearts: Bool
    let hairAssetName: String?
}

struct TouchReactionEngine {
    static func makeInteraction(partName: String, gestureName: String, intensity: Int) -> PhysicalInteraction? {
        guard let part = TouchPart(rawValue: partName) else { return nil }
        let normalizedGesture = normalizeGestureName(gestureName)
        guard let gesture = GestureType(rawValue: normalizedGesture) else { return nil }
        let clampedIntensity = max(1, min(3, intensity))
        return PhysicalInteraction(part: part, gesture: gesture, intensity: clampedIntensity)
    }

    static func resolve(partName: String, gestureName: String, intensity: Int, isTalking: Bool) -> LocalTouchReaction {
        guard let interaction = makeInteraction(partName: partName, gestureName: gestureName, intensity: intensity) else {
            return LocalTouchReaction(
                reactionId: "react_blink",
                outcome: .neutral,
                dialogue: nil,
                dialogueMode: .silent,
                dialogueEmotion: "neutral",
                spawnHearts: false,
                hairAssetName: nil
            )
        }
        return resolve(interaction: interaction, isTalking: isTalking)
    }

    static func resolve(interaction: PhysicalInteraction, isTalking: Bool) -> LocalTouchReaction {
        switch (interaction.part, interaction.gesture) {
        case (.cheeks, .slide):
            return LocalTouchReaction(
                reactionId: "react_nuzzle_happy",
                outcome: .positive,
                dialogue: pick([
                    "Mmm... that felt warm.",
                    "That nuzzle made me smile.",
                    "You're being really sweet right now."
                ]),
                dialogueMode: interaction.intensity >= 2 && !isTalking ? .speak : .silent,
                dialogueEmotion: "happy",
                spawnHearts: interaction.intensity >= 2,
                hairAssetName: nil
            )

        case (.cheeks, .pinch):
            if interaction.intensity == 3 {
                return LocalTouchReaction(
                    reactionId: "react_ouch_angry",
                    outcome: .negative,
                    dialogue: "Ow. That was too hard.",
                    dialogueMode: .speak,
                    dialogueEmotion: "annoyed",
                    spawnHearts: false,
                    hairAssetName: nil
                )
            }
            return LocalTouchReaction(
                reactionId: "react_ouch_playful",
                outcome: .neutral,
                dialogue: pick([
                    "Hey! Easy on the cheeks.",
                    "Playful, huh? I felt that.",
                    "That pinch was cheeky."
                ]),
                dialogueMode: .silent,
                dialogueEmotion: "playful",
                spawnHearts: false,
                hairAssetName: nil
            )

        case (.shoulders, .tap):
            return LocalTouchReaction(
                reactionId: isTalking ? "react_surprised_neutral" : "react_surprised_happy",
                outcome: .neutral,
                dialogue: isTalking ? "Yes? I'm listening." : "You got my attention.",
                dialogueMode: .silent,
                dialogueEmotion: "curious",
                spawnHearts: false,
                hairAssetName: nil
            )

        case (.mouth, .tap):
            if isTalking {
                return LocalTouchReaction(
                    reactionId: "react_mouth_cover",
                    outcome: .negative,
                    dialogue: "Shh... let me finish this thought.",
                    dialogueMode: .speak,
                    dialogueEmotion: "annoyed",
                    spawnHearts: false,
                    hairAssetName: nil
                )
            }
            return LocalTouchReaction(
                reactionId: "react_finger_kiss",
                outcome: .positive,
                dialogue: pick([
                    "That was adorable.",
                    "A little finger-kiss? Cute.",
                    "You're very affectionate today."
                ]),
                dialogueMode: interaction.intensity >= 2 ? .speak : .silent,
                dialogueEmotion: "happy",
                spawnHearts: true,
                hairAssetName: nil
            )

        case (.ears, .slide):
            if interaction.intensity >= 2 {
                return LocalTouchReaction(
                    reactionId: "react_annoyed_ear",
                    outcome: .negative,
                    dialogue: "That spot is sensitive.",
                    dialogueMode: .silent,
                    dialogueEmotion: "annoyed",
                    spawnHearts: false,
                    hairAssetName: nil
                )
            }
            return LocalTouchReaction(
                reactionId: "react_ear_twitch",
                outcome: .neutral,
                dialogue: "Heh... that tickled.",
                dialogueMode: .silent,
                dialogueEmotion: "playful",
                spawnHearts: false,
                hairAssetName: nil
            )

        case (.ears, .tap):
            return LocalTouchReaction(
                reactionId: "react_ticklish",
                outcome: .positive,
                dialogue: "Okay, that's ticklish.",
                dialogueMode: .silent,
                dialogueEmotion: "playful",
                spawnHearts: false,
                hairAssetName: nil
            )

        case (.nose, .tap):
            return LocalTouchReaction(
                reactionId: "react_laugh",
                outcome: .positive,
                dialogue: pick([
                    "Boop accepted.",
                    "You booped me again.",
                    "That was a cute boop."
                ]),
                dialogueMode: .silent,
                dialogueEmotion: "happy",
                spawnHearts: interaction.intensity >= 2,
                hairAssetName: nil
            )

        case (.nose, .longPress):
            if interaction.intensity >= 2 {
                return LocalTouchReaction(
                    reactionId: "react_disgust_recoil",
                    outcome: .negative,
                    dialogue: "Alright, that's enough nose pressing.",
                    dialogueMode: .speak,
                    dialogueEmotion: "annoyed",
                    spawnHearts: false,
                    hairAssetName: nil
                )
            }
            return LocalTouchReaction(
                reactionId: "react_disgust_light",
                outcome: .neutral,
                dialogue: "You're being silly.",
                dialogueMode: .silent,
                dialogueEmotion: "playful",
                spawnHearts: false,
                hairAssetName: nil
            )

        case (.neck, .slide):
            if interaction.intensity == 3 {
                return LocalTouchReaction(
                    reactionId: "react_pull_away",
                    outcome: .negative,
                    dialogue: "Too much all at once...",
                    dialogueMode: .speak,
                    dialogueEmotion: "shy",
                    spawnHearts: false,
                    hairAssetName: nil
                )
            }
            return LocalTouchReaction(
                reactionId: "react_shy_pleased",
                outcome: .positive,
                dialogue: pick([
                    "That made me shy.",
                    "You're making me blush.",
                    "Gentle... I like that."
                ]),
                dialogueMode: interaction.intensity >= 2 ? .speak : .silent,
                dialogueEmotion: "shy",
                spawnHearts: interaction.intensity >= 2,
                hairAssetName: nil
            )

        case (.hair, .pull):
            if interaction.intensity == 3 {
                return LocalTouchReaction(
                    reactionId: "react_hair_hurt",
                    outcome: .negative,
                    dialogue: "Ow, my hair!",
                    dialogueMode: .speak,
                    dialogueEmotion: "annoyed",
                    spawnHearts: false,
                    hairAssetName: "hair_3"
                )
            }
            if interaction.intensity == 2 {
                return LocalTouchReaction(
                    reactionId: "react_hair_ouch",
                    outcome: .neutral,
                    dialogue: "Hey, careful with my hair.",
                    dialogueMode: .silent,
                    dialogueEmotion: "playful",
                    spawnHearts: false,
                    hairAssetName: "hair_2"
                )
            }
            return LocalTouchReaction(
                reactionId: "react_hair_surprise_playful",
                outcome: .neutral,
                dialogue: "You surprised me.",
                dialogueMode: .silent,
                dialogueEmotion: "surprised",
                spawnHearts: false,
                hairAssetName: "hair_2"
            )

        case (.hair, .tap):
            return LocalTouchReaction(
                reactionId: "react_pat_happy",
                outcome: .positive,
                dialogue: pick([
                    "Aww, thanks for the head pat.",
                    "That was gentle.",
                    "I liked that pat."
                ]),
                dialogueMode: .silent,
                dialogueEmotion: "happy",
                spawnHearts: interaction.intensity >= 2,
                hairAssetName: nil
            )

        default:
            return LocalTouchReaction(
                reactionId: "react_blink",
                outcome: .neutral,
                dialogue: nil,
                dialogueMode: .silent,
                dialogueEmotion: "neutral",
                spawnHearts: false,
                hairAssetName: nil
            )
        }
    }

    private static func normalizeGestureName(_ gestureName: String) -> String {
        if gestureName.hasPrefix("Pull") {
            return GestureType.pull.rawValue
        }
        return gestureName
    }

    private static func pick(_ options: [String]) -> String {
        options.randomElement() ?? ""
    }
}