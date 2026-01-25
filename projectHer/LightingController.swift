import SpriteKit

final class LightingController {
    private weak var scene: AvatarScene?
    private weak var puppet: SKSpriteNode?

    private let overlay = SKSpriteNode(color: .clear, size: .zero)
    private let sun = SKShapeNode(circleOfRadius: 36)
    private let moon = SKShapeNode(circleOfRadius: 28)
    private let shadow = SKSpriteNode()

    init(scene: AvatarScene, puppet: SKSpriteNode) {
        self.scene = scene
        self.puppet = puppet
        setupOverlay()
        setupCelestials()
        setupShadow()
    }

    func update(timeOfDay hours: CGFloat) {
        let normalized = hours.truncatingRemainder(dividingBy: 24) / 24
        updateBackground(normalized)
        updateOverlay(normalized)
        updatePuppetTint(normalized)
        updateShadow(normalized)
        updateCelestials(normalized)
        updateWeatherBridge(normalized)
    }

    private func setupOverlay() {
        guard let scene = scene else { return }
        overlay.size = scene.size
        overlay.zPosition = 200
        overlay.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        overlay.blendMode = .screen
        overlay.color = .clear
        overlay.alpha = 0
        scene.addChild(overlay)
    }

    private func setupCelestials() {
        guard let scene = scene else { return }
        sun.fillColor = SKColor(red: 1, green: 0.82, blue: 0.4, alpha: 1)
        sun.strokeColor = .clear
        sun.glowWidth = 14
        sun.zPosition = -50
        moon.fillColor = SKColor(red: 0.8, green: 0.86, blue: 1, alpha: 0.9)
        moon.strokeColor = .clear
        moon.glowWidth = 10
        moon.zPosition = -50
        scene.addChild(sun)
        scene.addChild(moon)
    }

    private func setupShadow() {
        guard let puppet = puppet else { return }
        shadow.size = CGSize(width: puppet.size.width * 0.9, height: 40)
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.0
        shadow.zPosition = puppet.zPosition - 5
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        shadow.texture = SKTexture(image: UIImage(
            systemName: "capsule.fill",
            variableValue: 0.7
        ) ?? UIImage())
        puppet.addChild(shadow)
        shadow.position = CGPoint(x: 0, y: -puppet.size.height * 0.52)
    }

    private func updateBackground(_ t: CGFloat) {
        guard let scene = scene else { return }
        let color = SKColor(
            red: lerp(0.16, 0.04, t),
            green: lerp(0.2, 0.05, t),
            blue: lerp(0.32, 0.12, t),
            alpha: 1
        )
        let dayColor = SKColor(red: 0.5, green: 0.74, blue: 0.95, alpha: 1)
        let dawnColor = SKColor(red: 0.96, green: 0.7, blue: 0.85, alpha: 1)
        let duskColor = SKColor(red: 0.4, green: 0.08, blue: 0.25, alpha: 1)

        switch t {
        case 0..<0.2:
            scene.backgroundColor = color.lerp(to: dawnColor, progress: t / 0.2)
        case 0.2..<0.6:
            scene.backgroundColor = dawnColor.lerp(to: dayColor, progress: (t - 0.2) / 0.4)
        case 0.6..<0.85:
            scene.backgroundColor = dayColor.lerp(to: duskColor, progress: (t - 0.6) / 0.25)
        default:
            scene.backgroundColor = duskColor.lerp(to: color, progress: (t - 0.85) / 0.15)
        }
    }

    private func updateOverlay(_ t: CGFloat) {
        overlay.alpha = 0.65
        switch t {
        case 0..<0.25: // dawn
            overlay.color = SKColor(red: 1, green: 0.94, blue: 0.78, alpha: 1)
            overlay.blendMode = .screen
        case 0.25..<0.65: // day
            overlay.color = SKColor(red: 1, green: 1, blue: 1, alpha: 0.0)
            overlay.alpha = 0
        case 0.65..<0.85: // golden hour
            overlay.color = SKColor(red: 1, green: 0.58, blue: 0.35, alpha: 1)
            overlay.blendMode = .screen
        default: // night
            overlay.color = SKColor(red: 0.04, green: 0.07, blue: 0.18, alpha: 1)
            overlay.blendMode = .multiply
            overlay.alpha = 0.75
        }
    }

    private func updatePuppetTint(_ t: CGFloat) {
        guard let puppet = puppet else { return }
        let nodes = puppet.children.compactMap { $0 as? SKSpriteNode } + [puppet]
        let tint: SKColor
        let blend: CGFloat

        switch t {
        case 0..<0.25: // dawn
            tint = SKColor(red: 1, green: 0.86, blue: 0.68, alpha: 1)
            blend = 0.2
        case 0.25..<0.65: // day
            tint = .white
            blend = 0
        case 0.65..<0.85: // sunset
            tint = SKColor(red: 1, green: 0.5, blue: 0.28, alpha: 1)
            blend = 0.25
        default: // night
            tint = SKColor(red: 0.4, green: 0.55, blue: 1, alpha: 1)
            blend = 0.4
        }

        nodes.forEach {
            $0.color = tint
            $0.colorBlendFactor = blend
        }
    }

    private func updateShadow(_ t: CGFloat) {
        let skew = cos(t * .pi * 2) * 0.35
        let length = 0.4 + (0.35 - abs(skew)) * 0.6
        shadow.alpha = t > 0.95 || t < 0.05 ? 0.05 : 0.35
        shadow.setScale(1)
        shadow.xScale = 1.35
        shadow.yScale = length
        shadow.zRotation = skew * 0.4
        shadow.position.x = skew * 120
    }

    private func updateCelestials(_ t: CGFloat) {
        guard let scene = scene else { return }
        let radius = max(scene.size.width, scene.size.height) * 0.45
        let angle = (t * .pi * 2) - (.pi / 2)

        let pos = CGPoint(
            x: cos(angle) * radius,
            y: sin(angle) * radius
        )

        sun.isHidden = !(0.15...0.8).contains(t)
        moon.isHidden = (0.2..<0.8).contains(t)

        sun.position = pos
        moon.position = pos
        sun.alpha = sun.isHidden ? 0 : 0.9
        moon.alpha = moon.isHidden ? 0 : 0.7
    }

    private func updateWeatherBridge(_ t: CGFloat) {
        guard let scene = scene else { return }
        let night = t >= 0.8 || t <= 0.2
        // We let LightingController handle night mode trigger for weather
        if t <= 0.12 {
            scene.weather.enable(.fog)
        } else {
            scene.weather.disable(.fog)
        }
        if night {
            scene.weather.enable([.starsDeep, .starsBright])
        } else {
            scene.weather.disable(.starsDeep)
            scene.weather.disable(.starsBright)
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }
}

private extension SKColor {
    func lerp(to: SKColor, progress: CGFloat) -> SKColor {
        let p = max(0, min(1, progress))
        var (r1, g1, b1, a1) = (CGFloat.zero, CGFloat.zero, CGFloat.zero, CGFloat.zero)
        var (r2, g2, b2, a2) = (CGFloat.zero, CGFloat.zero, CGFloat.zero, CGFloat.zero)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(
            red: r1 + (r2 - r1) * p,
            green: g1 + (g2 - g1) * p,
            blue: b1 + (b2 - b1) * p,
            alpha: a1 + (a2 - a1) * p
        )
    }
}
