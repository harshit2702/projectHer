import SpriteKit

extension AvatarScene {
    
    // --- Helper for Mouth ---
    func updateMouth(name: String) {
        guard mouth != nil else { return }
        mouth.texture = SKTexture(imageNamed: name)
        if name == "mouth_ah" {
            mouth.position.x = 10
            mouth.setScale(0.8)
        } else {
            mouth.position.x = -10
            mouth.setScale(1.0)
        }
    }

    // --- Phase 2: Reaction Logic ---
    func handleReaction(part: String, type: String, intensity: GestureIntensity) {
        // Special case for Hair Pull directions
        if part == "Hair" && type.hasPrefix("Pull") {
            // Extract direction string (e.g. "Pull Left" -> "Left")
            let direction = type.replacingOccurrences(of: "Pull ", with: "")
            triggerHaptic(type: "medium")
            reactHairPull(direction: direction, intensity: intensity)
            return
        }
        
        switch (part, type) {
        case ("Cheeks", "Slide"):
            triggerHaptic(type: "light")
            reactNuzzle()
        case ("Cheeks", "Pinch"):
            triggerHaptic(type: "heavy")
            reactOuch(intensity: intensity)
        case ("Shoulders", "Tap"):
            triggerHaptic(type: "medium")
            reactSurprised()
        case ("Mouth", "Tap"):
            triggerHaptic(type: "light")
            if isTalking {
                stopTalk()
            } else {
                reactFingerKiss(at: touchStartLocation)
            }
        case ("Ears", "Slide"):
            triggerHaptic(type: "warning")
            reactAnnoyed()
        case ("Ears", "Tap"):
            triggerHaptic(type: "medium")
            reactTicklish()
        case ("Nose", "Tap"):
            triggerHaptic(type: "success")
            reactLaugh()
        case ("Nose", "Long Press"):
            triggerHaptic(type: "heavy")
            reactDisgust(intensity: intensity)
        case ("Neck", "Slide"):
            triggerHaptic(type: "light")
            reactShyLaugh()
        default:
            break
        }
    }
    
    // --- Reaction Implementations ---
    
    func reactHairPull(direction: String, intensity: GestureIntensity) {
        brows.texture = SKTexture(imageNamed: "brow_up")
        
        // Intensity 3: Crying
        if intensity == .intense {
            eyes.texture = SKTexture(imageNamed: "both_eye_tear_flowing")
            updateMouth(name: "mouth_ah")
        } else {
            updateMouth(name: "mouth_open") // Shocked mouth
            
            switch direction {
            case "Left":
                eyes.texture = SKTexture(imageNamed: "both_eye_left")
            case "Right":
                eyes.texture = SKTexture(imageNamed: "both_eye_right")
            case "Up":
                eyes.texture = SKTexture(imageNamed: "both_eye_up")
            case "Down":
                eyes.texture = SKTexture(imageNamed: "both_eye_towards_nose")
                brows.texture = SKTexture(imageNamed: "brow_in") // Cross-eyed look often pairs with brow in
            default:
                eyes.texture = SKTexture(imageNamed: "eye_open")
            }
        }
        
        // Reset after a moment
        let wait = SKAction.wait(forDuration: 1.0)
        let reset = SKAction.run { [weak self] in
            self?.eyes.texture = SKTexture(imageNamed: "eye_open")
            self?.brows.texture = SKTexture(imageNamed: "brow_neutral")
            self?.updateMouth(name: "mouth_neutral")
        }
        self.run(SKAction.sequence([wait, reset]))
    }
    
    func reactNuzzle() {
        // Gentle smile and slight head tilt towards touch
        brows.texture = SKTexture(imageNamed: "brow_neutral")
        eyes.texture = SKTexture(imageNamed: "eye_close") // Content closed eyes
        updateMouth(name: "mouth_neutral")
        
        let tilt = SKAction.rotate(byAngle: 0.05, duration: 0.5)
        let back = SKAction.rotate(byAngle: -0.05, duration: 0.5)
        body.run(SKAction.sequence([tilt, back]))
    }
    
    func reactOuch(intensity: GestureIntensity = .moderate) {
        // Pain/Shock
        brows.texture = SKTexture(imageNamed: "brow_in")
        
        if intensity == .intense {
            eyes.texture = SKTexture(imageNamed: "both_eye_tear_flowing") // Crying for intense pinch
            updateMouth(name: "mouth_ah")
        } else {
            eyes.texture = SKTexture(imageNamed: "both_eye_teary") // Teary eyes
            updateMouth(name: "mouth_ah")
        }
        
        // Quick shake
        let shakeLeft = SKAction.rotate(byAngle: 0.05, duration: 0.05)
        let shakeRight = SKAction.rotate(byAngle: -0.1, duration: 0.1)
        let shakeBack = SKAction.rotate(byAngle: 0.05, duration: 0.05)
        body.run(SKAction.sequence([shakeLeft, shakeRight, shakeBack]))
    }
    
    func reactSurprised() {
        setSurprised()
        let jump = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let land = SKAction.moveBy(x: 0, y: -10, duration: 0.2)
        body.run(SKAction.sequence([jump, land]))
    }
    
    func reactFingerKiss(at location: CGPoint) {
        brows.texture = SKTexture(imageNamed: "brow_neutral")
        eyes.texture = SKTexture(imageNamed: "eye_close")
        updateMouth(name: "mouth_neutral")
        
        spawnHearts(at: location)
    }
    
    func reactAnnoyed() {
        brows.texture = SKTexture(imageNamed: "brow_in")
        eyes.texture = SKTexture(imageNamed: "left_eye_blink")
        updateMouth(name: "mouth_neutral")
    }
    
    func reactTicklish() {
        brows.texture = SKTexture(imageNamed: "brow_up")
        eyes.texture = SKTexture(imageNamed: "eye_half")
        updateMouth(name: "mouth_open")
        
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.03, duration: 0.1),
            SKAction.rotate(byAngle: -0.06, duration: 0.2),
            SKAction.rotate(byAngle: 0.03, duration: 0.1)
        ])
        body.run(wiggle)
    }
    
    func reactLaugh() {
        setHappy()
        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.1),
            SKAction.moveBy(x: 0, y: -5, duration: 0.1),
            SKAction.moveBy(x: 0, y: 5, duration: 0.1),
            SKAction.moveBy(x: 0, y: -5, duration: 0.1)
        ])
        body.run(bounce)
    }
    
    func reactDisgust(intensity: GestureIntensity = .moderate) {
        brows.texture = SKTexture(imageNamed: "brow_in")
        eyes.texture = SKTexture(imageNamed: "eye_half")
        updateMouth(name: "mouth_neutral")
        
        let scaleDuration = (intensity == .intense) ? 0.4 : 0.2 // Longer recoil for intense
        
        let recoil = SKAction.sequence([
            SKAction.scale(to: 0.33, duration: scaleDuration),
            SKAction.wait(forDuration: 0.5),
            SKAction.scale(to: 0.35, duration: 0.3)
        ])
        body.run(recoil)
    }
    
    func reactShyLaugh() {
        brows.texture = SKTexture(imageNamed: "brow_up")
        eyes.texture = SKTexture(imageNamed: "both_eye_left")
        updateMouth(name: "mouth_open")
        
        let shrug = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.3),
            SKAction.rotate(byAngle: 0.05, duration: 0.3),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.moveBy(x: 0, y: -5, duration: 0.3),
                SKAction.rotate(byAngle: -0.05, duration: 0.3)
            ])
        ])
        body.run(shrug)
    }
    
    func spawnHearts(at location: CGPoint) {
        for _ in 0..<5 {
            let heart = SKShapeNode(circleOfRadius: 5)
            heart.fillColor = .systemPink
            heart.strokeColor = .clear
            heart.position = location
            heart.zPosition = 200
            addChild(heart)
            
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 50...100), duration: 1.5)
            let fadeOut = SKAction.fadeOut(withDuration: 1.5)
            let scaleDown = SKAction.scale(to: 0, duration: 1.5)
            let group = SKAction.group([moveUp, fadeOut, scaleDown])
            
            heart.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // --- Emotions (Instant) ---
    func setHappy() {
        guard body != nil else { return }
        stopPreset()
        updateMouth(name: "mouth_open")
        eyes.texture = SKTexture(imageNamed: "eye_open")
        brows.texture = SKTexture(imageNamed: "brow_neutral")
    }
    
    func setSad() {
        guard body != nil else { return }
        stopPreset()
        eyes.texture = SKTexture(imageNamed: "both_eye_tear_flowing")
        updateMouth(name: "mouth_neutral")
        brows.texture = SKTexture(imageNamed: "brow_in")
    }
    
    func setSurprised() {
        guard body != nil else { return }
        stopPreset()
        updateMouth(name: "mouth_ah")
        eyes.texture = SKTexture(imageNamed: "eye_open")
        brows.texture = SKTexture(imageNamed: "brow_up")
    }
    
    func setThinking() {
        guard body != nil else { return }
        stopPreset()
        eyes.texture = SKTexture(imageNamed: "both_eye_up")
        updateMouth(name: "mouth_neutral")
        brows.texture = SKTexture(imageNamed: "brow_in")
    }
    
    func setFocus() {
        guard body != nil else { return }
        stopPreset()
        eyes.texture = SKTexture(imageNamed: "both_eye_towards_nose")
        updateMouth(name: "mouth_neutral")
        brows.texture = SKTexture(imageNamed: "brow_in")
    }

    func setCurious() {
        guard body != nil else { return }
        stopPreset()
        brows.texture = SKTexture(imageNamed: "brow_up")
        eyes.texture = SKTexture(imageNamed: "both_eye_up")
        
        let wait = SKAction.wait(forDuration: 1.5)
        let reset = SKAction.run {
            self.brows.texture = SKTexture(imageNamed: "brow_neutral")
            self.eyes.texture = SKTexture(imageNamed: "eye_open")
        }
        self.run(SKAction.sequence([wait, reset]))
    }

    func setTension() {
        guard body != nil else { return }
        stopPreset()
        brows.texture = SKTexture(imageNamed: "brow_in")
        eyes.texture = SKTexture(imageNamed: "both_eye_towards_nose")
        updateMouth(name: "mouth_neutral")
    }
    
    // --- Talking Variations (Looping) ---

    func stopTalk() {
        guard mouth != nil else { return }
        activeTalk = nil
        isTalking = false
        mouth.removeAllActions()
        mouth.removeAction(forKey: "talk")
        updateMouth(name: "mouth_neutral")
        mouth.yScale = (mouth.texture?.description.contains("ah") == true) ? 0.8 : 1.0
    }

    func startTalkVar1() {
        guard mouth != nil else { return }
        stopTalk()
        activeTalk = "talk1"
        let frames = ["mouth_neutral", "mouth_open", "mouth_neutral", "mouth_ah", "mouth_neutral"]
        var actions: [SKAction] = []
        for f in frames {
            actions.append(SKAction.run { self.updateMouth(name: f) })
            actions.append(SKAction.wait(forDuration: 0.15))
        }
        mouth.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "talk")
    }

    func startTalkVar2() {
        guard mouth != nil else { return }
        stopTalk()
        activeTalk = "talk2"
        let frames = ["mouth_neutral", "mouth_ah", "mouth_open", "mouth_ah", "mouth_neutral"]
        var actions: [SKAction] = []
        for f in frames {
            actions.append(SKAction.run { self.updateMouth(name: f) })
            actions.append(SKAction.wait(forDuration: 0.1))
        }
        mouth.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "talk")
    }

    func startTalkVar3() {
        guard mouth != nil else { return }
        stopTalk()
        activeTalk = "talk3"
        let frames = ["mouth_neutral", "mouth_open", "mouth_neutral"]
        var actions: [SKAction] = []
        for f in frames {
            actions.append(SKAction.run { self.updateMouth(name: f) })
            actions.append(SKAction.wait(forDuration: 0.3))
        }
        mouth.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "talk")
    }

    func startTalkVar4() {
        guard mouth != nil else { return }
        stopTalk()
        activeTalk = "talk4"
        let frames = ["mouth_open", "mouth_ah", "mouth_open", "mouth_ah"]
        var actions: [SKAction] = []
        for f in frames {
            actions.append(SKAction.run { self.updateMouth(name: f) })
            actions.append(SKAction.wait(forDuration: 0.12))
        }
        mouth.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "talk")
    }
    
    // --- Natural Talk Logic ---
    func startTalkNatural() {
        guard mouth != nil else { return }
        stopTalk()
        activeTalk = "natural"
        isTalking = true
        scheduleNextMouth()
    }
    
    func scheduleNextMouth() {
        guard isTalking, mouth != nil else { return }

        if Double.random(in: 0...1) < 0.20 {
            let pause = SKAction.sequence([
                .run { [weak self] in
                    self?.updateMouth(name: "mouth_neutral")
                },
                .wait(forDuration: Double.random(in: 0.15...0.7))
            ])
            mouth.run(pause) { [weak self] in self?.scheduleNextMouth() }
            return
        }

        var phoneme = pickWeighted([
            ("mouth_open", 0.55),
            ("mouth_ah",   0.30),
            ("mouth_neutral", 0.15)
        ])
        
        if phoneme == lastPhoneme {
            phonemeRepeatCount += 1
            if phonemeRepeatCount >= 2 {
                while phoneme == lastPhoneme {
                     phoneme = pickWeighted([("mouth_open", 0.55), ("mouth_ah", 0.30), ("mouth_neutral", 0.15)])
                }
                phonemeRepeatCount = 0
            }
        } else {
            phonemeRepeatCount = 0
        }
        lastPhoneme = phoneme

        let d = Double.random(in: 0.08...0.18)
        let baseScale: CGFloat = (phoneme == "mouth_ah") ? 0.8 : 1.0

        let jawDown = SKAction.group([
            .moveBy(x: 0, y: -1.5, duration: d * 0.5),
            .scaleY(to: baseScale * 1.05, duration: d * 0.5)
        ])
        let jawUp = SKAction.group([
            .moveBy(x: 0, y: 1.5, duration: d * 0.5),
            .scaleY(to: baseScale, duration: d * 0.5)
        ])
        
        if Double.random(in: 0...1) < 0.3 {
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 1.0, duration: d),
                SKAction.moveBy(x: 0, y: -1.0, duration: d)
            ])
            body.run(bob)
        }

        let step = SKAction.sequence([
            .run { [weak self] in
                self?.updateMouth(name: phoneme)
            },
            jawDown,
            jawUp,
            .wait(forDuration: Double.random(in: 0.02...0.08))
        ])

        mouth.run(step) { [weak self] in self?.scheduleNextMouth() }
    }
    
    private func pickWeighted(_ items: [(String, Double)]) -> String {
        let total = items.reduce(0.0) { $0 + $1.1 }
        var r = Double.random(in: 0..<total)
        for (name, w) in items {
            r -= w
            if r <= 0 { return name }
        }
        return items.last?.0 ?? "mouth_neutral"
    }
    
    // --- Presets (Looping Sequences) ---
    func stopPreset() {
        guard eyes != nil else { return }
        activePreset = nil
        eyes.removeAction(forKey: "preset")
        eyes.texture = SKTexture(imageNamed: "eye_open")
        brows.texture = SKTexture(imageNamed: "brow_neutral")
        updateMouth(name: "mouth_neutral")
    }

    func startWinkLoop() {
        guard eyes != nil else { return }
        stopPreset()
        activePreset = "wink"
        let wink = SKAction.setTexture(SKTexture(imageNamed: "left_eye_blink"))
        let open = SKAction.setTexture(SKTexture(imageNamed: "eye_open"))
        let wait = SKAction.wait(forDuration: 0.5)
        let loopWait = SKAction.wait(forDuration: 1.5)
        
        let seq = SKAction.sequence([wink, wait, open, loopWait])
        eyes.run(SKAction.repeatForever(seq), withKey: "preset")
    }
    
    func startEyeScanLoop() {
        guard eyes != nil else { return }
        stopPreset()
        activePreset = "scan"
        let left = SKAction.setTexture(SKTexture(imageNamed: "both_eye_left"))
        let center = SKAction.setTexture(SKTexture(imageNamed: "both_eye_towards_nose"))
        let right = SKAction.setTexture(SKTexture(imageNamed: "both_eye_right"))
        let open = SKAction.setTexture(SKTexture(imageNamed: "eye_open"))
        let wait = SKAction.wait(forDuration: 0.5)
        let loopWait = SKAction.wait(forDuration: 2.0)
        
        let seq = SKAction.sequence([left, wait, center, wait, right, wait, open, loopWait])
        eyes.run(SKAction.repeatForever(seq), withKey: "preset")
    }
    
    func startCryingLoop() {
        guard eyes != nil else { return }
        stopPreset()
        activePreset = "cry"
        let teary = SKAction.setTexture(SKTexture(imageNamed: "both_eye_teary"))
        let flowingSingle = SKAction.setTexture(SKTexture(imageNamed: "single_eye_tear_flowing"))
        let flowingBoth = SKAction.setTexture(SKTexture(imageNamed: "both_eye_tear_flowing"))
        let wait = SKAction.wait(forDuration: 1.0)
        let loopWait = SKAction.wait(forDuration: 2.0)
        
        let seq = SKAction.sequence([teary, wait, flowingSingle, wait, flowingBoth, loopWait])
        eyes.run(SKAction.repeatForever(seq), withKey: "preset")
    }
    
    func startFlirtyLoop() {
        guard eyes != nil else { return }
        stopPreset()
        activePreset = "flirty"
        brows.texture = SKTexture(imageNamed: "brow_up")
        
        let wink = SKAction.setTexture(SKTexture(imageNamed: "right_eye_blink"))
        let open = SKAction.setTexture(SKTexture(imageNamed: "eye_open"))
        let wait = SKAction.wait(forDuration: 0.5)
        let loopWait = SKAction.wait(forDuration: 2.0)
        
        let seq = SKAction.sequence([wink, wait, open, loopWait])
        eyes.run(SKAction.repeatForever(seq), withKey: "preset")
    }
    
    func startTiredLoop() {
        guard eyes != nil else { return }
        stopPreset()
        activePreset = "tired"
        let blink = SKAction.setTexture(SKTexture(imageNamed: "left_eye_blink"))
        let half = SKAction.setTexture(SKTexture(imageNamed: "eye_half"))
        let open = SKAction.setTexture(SKTexture(imageNamed: "eye_open"))
        
        let seq = SKAction.sequence([
            blink, SKAction.wait(forDuration: 0.2),
            half, SKAction.wait(forDuration: 1.5),
            open, SKAction.wait(forDuration: 1.5)
        ])
        eyes.run(SKAction.repeatForever(seq), withKey: "preset")
    }
}
