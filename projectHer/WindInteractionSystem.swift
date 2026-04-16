// WindInteractionSystem.swift - Environmental wind effects

import Foundation
import CoreGraphics
import simd
import SwiftUI
import Combine

struct WindState: Codable {
    var speed: Float // 0-1 normalized
    var direction: SIMD2<Float> // Unit vector
    var gustiness: Float // 0-1, how variable
    var name: String
    var metersPerSecond: Float
    
    static let calm = WindState(speed: 0.0, direction: [1, 0], gustiness: 0.0, name: "calm", metersPerSecond: 0)
    static let gentle = WindState(speed: 0.2, direction: [0.7, 0.3], gustiness: 0.2, name: "gentle breeze", metersPerSecond: 2.4)
    static let moderate = WindState(speed: 0.5, direction: [0.8, 0.2], gustiness: 0.4, name: "moderate wind", metersPerSecond: 6.0)
    static let strong = WindState(speed: 0.8, direction: [0.9, 0.1], gustiness: 0.6, name: "strong wind", metersPerSecond: 9.6)
}

 @MainActor
class WindManager: ObservableObject {
    static let shared = WindManager()
    
    @Published var currentWind: WindState = .calm
    @Published var locationName: String = "Current Location"
    @Published var conditionSummary: String = "Clear"
    
    func update(from environment: WeatherEnvironment) {
        let speed = environment.windSpeedNormalized
        let direction = normalizedDirection(from: environment.windDX)
        let gustiness = min(0.9, (speed * 0.65) + Float(environment.precipitationLevel) * 0.25)

        withAnimation(.easeInOut(duration: 0.8)) {
            currentWind = WindState(
                speed: speed,
                direction: direction,
                gustiness: gustiness,
                name: descriptorFor(speed: speed, precipitation: Float(environment.precipitationLevel)),
                metersPerSecond: environment.windSpeedMetersPerSecond
            )
            locationName = environment.locationName
            conditionSummary = environment.conditionSummary
        }
    }
    
    func getWindEffectContext() -> String {
        if currentWind.speed < 0.1 { return "" }
        return "[WIND EFFECTS] The wind is \(currentWind.name) (\(String(format: "%.1f", currentWind.metersPerSecond)) m/s)"
    }
    
    // Convert to game engine value (dx for WeatherController)
    var windDX: CGFloat {
        return CGFloat(currentWind.speed * 200 * currentWind.direction.x)
    }

    private func normalizedDirection(from windDX: CGFloat) -> SIMD2<Float> {
        let horizontal = Float(max(-1, min(1, windDX / 240)))
        let vector = SIMD2<Float>(horizontal, 0.12)
        let length = simd_length(vector)
        if length < 0.0001 {
            return SIMD2<Float>(1, 0)
        }
        return vector / length
    }

    private func descriptorFor(speed: Float, precipitation: Float) -> String {
        if speed < 0.08 {
            return "calm"
        }
        if speed < 0.25 {
            return precipitation > 0.5 ? "soft rainy breeze" : "gentle breeze"
        }
        if speed < 0.6 {
            return precipitation > 0.5 ? "gusty rain wind" : "steady wind"
        }
        return precipitation > 0.5 ? "stormy wind" : "strong wind"
    }
}
