// WeatherKitManager.swift
// Fetches real weather at the user's location via WeatherKit and maps it to
// avatar scene effects (WeatherController.Effect) and wind state.

import Foundation
import CoreLocation
import WeatherKit
import SpriteKit

/// Published environment data derived from WeatherKit.
struct WeatherEnvironment {
    var effects: [WeatherController.Effect]
    var windDX: CGFloat   // Horizontal wind force for scene emitters
    var isDaytime: Bool
    
    static let empty = WeatherEnvironment(effects: [], windDX: 0, isDaytime: true)
}

final class WeatherKitManager: NSObject, ObservableObject {
    static let shared = WeatherKitManager()

    @Published private(set) var environment: WeatherEnvironment = .empty
    @Published private(set) var isAuthorized: Bool = false

    /// Converts m/s to a scene-space horizontal acceleration value that looks natural.
    private static let windSpeedToSceneUnits: Double = 20.0
    private let weatherService = WeatherService.shared
    private var refreshTask: Task<Void, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    func start() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func stop() {
        refreshTask?.cancel()
    }

    // MARK: - Private

    private func fetchWeather(at location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            await MainActor.run {
                self.environment = Self.map(weather: weather)
            }
        } catch {
            print("⚠️ WeatherKit fetch failed: \(error.localizedDescription)")
        }
    }

    private static func map(weather: Weather) -> WeatherEnvironment {
        let current = weather.currentWeather

        var effects: [WeatherController.Effect] = []
        switch current.condition {
        case .rain, .heavyRain, .freezingRain,
             .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms:
            effects = [.rain, .fog]
        case .drizzle, .freezingDrizzle, .sunShowers:
            effects = [.rain]
        case .snow, .heavySnow, .blizzard, .blowingSnow, .sleet:
            effects = [.snowBackground, .snowForeground]
        case .flurries, .sunFlurries:
            effects = [.snowBackground]
        case .fog, .haze, .smoky:
            effects = [.fog]
        case .windy, .blowingDust, .tropicalStorm, .hurricane:
            effects = [.leaves]
        default:
            break
        }

        if !current.isDaylight {
            effects += [.starsDeep, .starsBright]
        }

        // Convert wind speed (m/s) and direction (degrees from North) to scene dx
        let speedMs = current.wind.speed.converted(to: .metersPerSecond).value
        let directionDeg = current.wind.direction.value
        let directionRad = directionDeg * .pi / 180.0
        let windDX = CGFloat(speedMs * sin(directionRad)) * Self.windSpeedToSceneUnits

        return WeatherEnvironment(effects: effects, windDX: windDX, isDaytime: current.isDaylight)
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            // try? is intentional: CancellationError from task cancellation is the only
            // expected error here, and the guard below handles that case explicitly.
            try? await Task.sleep(for: .seconds(900)) // refresh every 15 min
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.locationManager.requestLocation() }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherKitManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.requestLocation()
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { [weak self] in
            await self?.fetchWeather(at: location)
            await MainActor.run { self?.scheduleRefresh() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
}
