import SpriteKit
import UIKit

final class WeatherController {
    enum Effect: Hashable {
        case starsDeep
        case starsBright
        case snowBackground
        case snowForeground
        case rain
        case fog
        case leaves
    }

    private weak var scene: SKScene?
    private var emitters: [Effect: SKEmitterNode] = [:]
    private var windDX: CGFloat = 0

    // Caches
    private static let cachedLeafTexture = WeatherController.makeLeafTexture()
    private static let cachedLeafColors = WeatherController.makeLeafColorSequence()
    private static let cachedLeafFlutter = WeatherController.makeLeafFlutterAction()
    private static let cachedFogTexture = WeatherController.makeFogTexture()
    private static let cachedRainTexture = WeatherController.rainTexture(length: 32, thickness: 1.6, alpha: 0.45)

    init(scene: SKScene) {
        self.scene = scene
    }

    func enable(_ effects: [Effect]) {
        effects.forEach { enable($0) }
    }

    func enable(_ effect: Effect) {
        guard let scene = scene else { return }
        let emitter = emitters[effect] ?? buildEmitter(for: effect, in: scene)
        emitters[effect] = emitter
        if emitter.parent == nil {
            scene.addChild(emitter)
        }
        let baseline = emitter.userData?["baseBirthRate"] as? CGFloat ?? emitter.particleBirthRate
        emitter.particleBirthRate = baseline
        emitter.isHidden = false
    }

    func disable(_ effect: Effect, lettingParticlesFinish: Bool = true) {
        guard let emitter = emitters[effect] else { return }
        emitter.particleBirthRate = 0
        guard !lettingParticlesFinish else { return }
        emitter.removeAllActions()
        emitter.removeFromParent()
        emitters.removeValue(forKey: effect)
    }
    
    func disableAll() {
        for effect in emitters.keys {
            disable(effect)
        }
    }
    
    func setWind(dx: CGFloat) {
        self.windDX = dx
        // Update active emitters that react to wind
        for (effect, emitter) in emitters {
            if effect == .snowBackground || effect == .snowForeground || effect == .rain || effect == .leaves || effect == .fog {
                emitter.xAcceleration = dx
            }
        }
    }

    func setNightMode(_ enabled: Bool) {
        if enabled {
            enable([.starsDeep, .starsBright])
        } else {
            disable(.starsDeep)
            disable(.starsBright)
        }
    }

    // MARK: - Emitter Factories
    private func buildEmitter(for effect: Effect, in scene: SKScene) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.targetNode = scene
        switch effect {
        case .starsDeep:
            configureStarsEmitter(emitter, intense: false, scene: scene)
        case .starsBright:
            configureStarsEmitter(emitter, intense: true, scene: scene)
        case .snowBackground:
            configureSnowEmitter(emitter, parallax: 0.5, scene: scene)
        case .snowForeground:
            configureSnowEmitter(emitter, parallax: 1.0, scene: scene)
        case .rain:
            configureRainEmitter(emitter, scene: scene)
        case .fog:
            configureFogEmitter(emitter, scene: scene)
        case .leaves:
            configureLeavesEmitter(emitter, scene: scene)
        }
        emitter.userData = ["baseBirthRate": emitter.particleBirthRate as NSNumber]
        return emitter
    }

    // Configuration logic (Simplified for brevity, matches reference)
    private func configureStarsEmitter(_ emitter: SKEmitterNode, intense: Bool, scene: SKScene) {
        emitter.particleTexture = WeatherController.circleTexture(radius: intense ? 3 : 2, blur: intense ? 5 : 3, alpha: intense ? 0.9 : 0.5)
        emitter.particleColor = .white
        emitter.particleBirthRate = intense ? 10 : 4
        emitter.particleLifetime = 14
        emitter.particleAlpha = intense ? 0.95 : 0.6
        emitter.particleSpeed = 0
        emitter.particlePositionRange = CGVector(dx: scene.size.width * 1.2, dy: scene.size.height * 1.2)
        emitter.zPosition = -100
    }

    private func configureSnowEmitter(_ emitter: SKEmitterNode, parallax: CGFloat, scene: SKScene) {
        emitter.particleTexture = WeatherController.circleTexture(radius: 3, blur: 2, alpha: 0.9)
        emitter.particleBirthRate = parallax > 0.8 ? 20 : 10
        emitter.particleLifetime = 10
        emitter.yAcceleration = -10 * parallax
        emitter.particlePositionRange = CGVector(dx: scene.size.width, dy: 0)
        emitter.position = CGPoint(x: 0, y: scene.size.height / 2)
        emitter.zPosition = parallax > 0.8 ? 50 : -20
    }

    private func configureRainEmitter(_ emitter: SKEmitterNode, scene: SKScene) {
        emitter.particleTexture = WeatherController.cachedRainTexture
        emitter.particleBirthRate = 100
        emitter.yAcceleration = -1000
        emitter.particlePositionRange = CGVector(dx: scene.size.width, dy: 0)
        emitter.position = CGPoint(x: 0, y: scene.size.height / 2)
        emitter.zPosition = 60
    }
    
    private func configureFogEmitter(_ emitter: SKEmitterNode, scene: SKScene) {
        emitter.particleTexture = WeatherController.cachedFogTexture
        emitter.particleBirthRate = 1
        emitter.particleLifetime = 20
        emitter.particleSpeed = 10
        emitter.xAcceleration = 2
        emitter.position = CGPoint(x: 0, y: -scene.size.height / 3)
        emitter.zPosition = 100
    }
    
    private func configureLeavesEmitter(_ emitter: SKEmitterNode, scene: SKScene) {
        emitter.particleTexture = WeatherController.cachedLeafTexture
        emitter.particleColorSequence = WeatherController.cachedLeafColors
        emitter.particleBirthRate = 2
        emitter.particleLifetime = 8
        emitter.yAcceleration = -20
        emitter.particleAction = WeatherController.cachedLeafFlutter
        emitter.position = CGPoint(x: 0, y: scene.size.height / 2)
        emitter.zPosition = 70
    }

    // Helpers
    private static func circleTexture(radius: CGFloat, blur: CGFloat, alpha: CGFloat) -> SKTexture {
        let diameter = (radius + blur) * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { ctx in
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let colors = [UIColor.white.withAlphaComponent(alpha).cgColor, UIColor.clear.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: diameter/2, options: .drawsAfterEndLocation)
            }
        }
        return SKTexture(image: image)
    }
    
    private static func rainTexture(length: CGFloat, thickness: CGFloat, alpha: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: thickness, height: length))
        let image = renderer.image { _ in
            UIColor.white.withAlphaComponent(alpha).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: thickness, height: length)).fill()
        }
        return SKTexture(image: image)
    }
    
    private static func makeFogTexture() -> SKTexture {
        return circleTexture(radius: 50, blur: 50, alpha: 0.3)
    }
    
    private static func makeLeafTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 20, height: 10))
        }
        return SKTexture(image: image)
    }
    
    private static func makeLeafColorSequence() -> SKKeyframeSequence {
        let colors = [UIColor.orange, UIColor.brown, UIColor.yellow]
        return SKKeyframeSequence(keyframeValues: colors, times: [0, 0.5, 1])
    }
    
    private static func makeLeafFlutterAction() -> SKAction {
        return SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 2))
    }
}
