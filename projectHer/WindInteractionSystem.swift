// WindInteractionSystem.swift - Environmental wind effects

import Foundation
import simd
import SwiftUI
import Combine

struct WindState: Codable {
    var speed: Float // 0-1 normalized
    var direction: SIMD2<Float> // Unit vector
    var gustiness: Float // 0-1, how variable
    var name: String
    
    static let calm = WindState(speed: 0.0, direction: [1, 0], gustiness: 0.0, name: "calm")
    static let gentle = WindState(speed: 0.2, direction: [0.7, 0.3], gustiness: 0.2, name: "gentle breeze")
    static let moderate = WindState(speed: 0.5, direction: [0.8, 0.2], gustiness: 0.4, name: "moderate wind")
    static let strong = WindState(speed: 0.8, direction: [0.9, 0.1], gustiness: 0.6, name: "strong wind")
}

 @MainActor
class WindManager: ObservableObject {
    static let shared = WindManager()
    
    @Published var currentWind: WindState = .calm
    
    // Mapping location types to wind
    private let locationWindMap: [String: WindState] = [
        "home": .calm,
        "indoor": .calm,
        "park": .gentle,
        "beach": .moderate,
        "mountain": .strong,
        "street": .gentle
    ]
    
    func updateForLocation(_ locationType: String) {
        if let wind = locationWindMap[locationType] {
            withAnimation(.easeInOut(duration: 1.0)) {
                currentWind = wind
            }
        } else {
            currentWind = .calm
        }
    }
    
    func getWindEffectContext() -> String {
        if currentWind.speed < 0.1 { return "" }
        return "[WIND EFFECTS] The wind is \(currentWind.name) (Speed: \(String(format: "%.1f", currentWind.speed)))"
    }
    
    // Convert to game engine value (dx for WeatherController)
    var windDX: CGFloat {
        return CGFloat(currentWind.speed * 200 * currentWind.direction.x)
    }
}
