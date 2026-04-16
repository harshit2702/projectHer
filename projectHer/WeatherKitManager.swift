// WeatherKitManager.swift
// Uses wttr.in with CoreLocation to fetch weather once per video-call session
// and map it to avatar scene effects.

import Foundation
import CoreLocation
import SpriteKit
import Combine

/// Published environment data derived from wttr.in.
struct WeatherEnvironment {
    var effects: [WeatherController.Effect]
    var windDX: CGFloat   // Horizontal wind force for scene emitters
    var isDaytime: Bool
    var localHour: CGFloat
    var cloudiness: CGFloat
    var precipitationLevel: CGFloat
    var conditionSummary: String
    var locationName: String
    var windSpeedMetersPerSecond: Float
    var windSpeedNormalized: Float
    
    static let empty = WeatherEnvironment(
        effects: [],
        windDX: 0,
        isDaytime: true,
        localHour: 12,
        cloudiness: 0,
        precipitationLevel: 0,
        conditionSummary: "Clear",
        locationName: "Current Location",
        windSpeedMetersPerSecond: 0,
        windSpeedNormalized: 0
    )
}

final class WeatherKitManager: NSObject, ObservableObject {
    static let shared = WeatherKitManager()

    @Published private(set) var environment: WeatherEnvironment = .empty
    @Published private(set) var isAuthorized: Bool = false

    /// Converts m/s to a scene-space horizontal acceleration value that looks natural.
    private static let windSpeedToSceneUnits: Double = 20.0
    private let locationManager = CLLocationManager()
    private var fetchTask: Task<Void, Never>?
    private var hasFetchedThisSession = false
    private var requestInFlight = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    func start() {
        guard !hasFetchedThisSession, !requestInFlight else { return }

        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            requestInFlight = true
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            isAuthorized = false
            break
        }
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
        requestInFlight = false
        hasFetchedThisSession = false
    }

    // MARK: - Private

    private func fetchWeather(at location: CLLocation) async {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        var components = URLComponents(string: "https://wttr.in/\(latitude),\(longitude)")
        components?.queryItems = [URLQueryItem(name: "format", value: "j1")]

        guard let url = components?.url else {
            print("⚠️ wttr.in URL creation failed")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("⚠️ wttr.in returned non-2xx status")
                return
            }

            let payload = try JSONDecoder().decode(WttrResponse.self, from: data)
            let environment = Self.map(response: payload, latitude: latitude, longitude: longitude)

            await MainActor.run {
                self.environment = environment
            }
        } catch {
            print("⚠️ wttr.in fetch failed: \(error.localizedDescription)")
        }
    }

    private static func map(response: WttrResponse, latitude: Double, longitude: Double) -> WeatherEnvironment {
        let current = response.current_condition?.first

        let descriptionText = current?.weatherDesc?.first?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Clear"
        let normalizedDescription = descriptionText.lowercased()

        let cloudPercent = Double(current?.cloudcover ?? "0") ?? 0
        let cloudiness = max(0, min(1, cloudPercent / 100.0))

        let precipMillimeters = Double(current?.precipMM ?? "0") ?? 0
        var precipitationLevel = max(0, min(1, precipMillimeters / 4.0))

        let windKmph = Double(current?.windspeedKmph ?? "0") ?? 0
        let speedMs = windKmph / 3.6
        let directionDeg = Double(current?.winddirDegree ?? "0") ?? 0
        let directionRad = directionDeg * .pi / 180.0
        let windDX = CGFloat(speedMs * sin(directionRad)) * Self.windSpeedToSceneUnits

        var effects: [WeatherController.Effect] = []

        if normalizedDescription.contains("snow") || normalizedDescription.contains("sleet") || normalizedDescription.contains("blizzard") || normalizedDescription.contains("flurr") {
            effects.append(.snowBackground)
            if precipitationLevel > 0.35 {
                effects.append(.snowForeground)
            }
            precipitationLevel = max(precipitationLevel, 0.4)
        }

        if normalizedDescription.contains("rain") || normalizedDescription.contains("drizzle") || normalizedDescription.contains("shower") || normalizedDescription.contains("storm") || normalizedDescription.contains("thunder") {
            effects.append(.rain)
            precipitationLevel = max(precipitationLevel, 0.25)
        }

        if normalizedDescription.contains("fog") || normalizedDescription.contains("mist") || normalizedDescription.contains("haze") || normalizedDescription.contains("smoke") {
            effects.append(.fog)
        }

        if normalizedDescription.contains("wind") || speedMs > 7 {
            effects.append(.leaves)
        }

        let localHourInt = Calendar.current.component(.hour, from: Date())
        let isDaytime = (6..<19).contains(localHourInt)
        if !isDaytime {
            effects.append(contentsOf: [.starsDeep, .starsBright])
        }

        var uniqueEffects: [WeatherController.Effect] = []
        for effect in effects where !uniqueEffects.contains(effect) {
            uniqueEffects.append(effect)
        }

        let nearest = response.nearest_area?.first
        let areaName = nearest?.areaName?.first?.value
        let regionName = nearest?.region?.first?.value
        let countryName = nearest?.country?.first?.value

        let locationName: String
        if let areaName, let regionName, !regionName.isEmpty, regionName != areaName {
            locationName = "\(areaName), \(regionName)"
        } else if let areaName {
            locationName = areaName
        } else if let countryName {
            locationName = countryName
        } else {
            locationName = String(format: "%.2f, %.2f", latitude, longitude)
        }

        let windSpeedNormalized = Float(min(speedMs / 12.0, 1.0))

        return WeatherEnvironment(
            effects: uniqueEffects,
            windDX: windDX,
            isDaytime: isDaytime,
            localHour: CGFloat(localHourInt),
            cloudiness: CGFloat(cloudiness),
            precipitationLevel: CGFloat(precipitationLevel),
            conditionSummary: descriptionText,
            locationName: locationName,
            windSpeedMetersPerSecond: Float(speedMs),
            windSpeedNormalized: windSpeedNormalized
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherKitManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            if !hasFetchedThisSession, !requestInFlight {
                requestInFlight = true
                manager.requestLocation()
            }
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            requestInFlight = false
            return
        }
        guard !hasFetchedThisSession else {
            requestInFlight = false
            return
        }

        hasFetchedThisSession = true
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            await self?.fetchWeather(at: location)
            await MainActor.run {
                self?.requestInFlight = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requestInFlight = false
        print("⚠️ Location error: \(error.localizedDescription)")
    }
}

private struct WttrResponse: Decodable {
    let current_condition: [WttrCurrentCondition]?
    let nearest_area: [WttrNearestArea]?
}

private struct WttrCurrentCondition: Decodable {
    let weatherDesc: [WttrTextValue]?
    let cloudcover: String?
    let precipMM: String?
    let windspeedKmph: String?
    let winddirDegree: String?
}

private struct WttrNearestArea: Decodable {
    let areaName: [WttrTextValue]?
    let region: [WttrTextValue]?
    let country: [WttrTextValue]?
}

private struct WttrTextValue: Decodable {
    let value: String?
}
