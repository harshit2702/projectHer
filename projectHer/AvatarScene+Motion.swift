import SpriteKit

extension AvatarScene {
    // --- External Control Methods ---

    func setBreathing(enabled: Bool) {
        guard body != nil else { return }
        isBreathingState = enabled
        if enabled {
            if body.action(forKey: "breathing") == nil {
                let breatheUp = SKAction.moveBy(x: 0, y: 8, duration: 2.5)
                let breatheDown = SKAction.moveBy(x: 0, y: -8, duration: 2.5)
                breatheUp.timingMode = .easeInEaseOut
                breatheDown.timingMode = .easeInEaseOut
                body.run(SKAction.repeatForever(SKAction.sequence([breatheUp, breatheDown])), withKey: "breathing")
            }
        } else {
            body.removeAction(forKey: "breathing")
        }
    }

    func setHeadTilt(enabled: Bool) {
        guard body != nil else { return }
        isHeadTilting = enabled
        if enabled {
            if body.action(forKey: "headTilt") == nil {
                let tiltSeq = SKAction.sequence([
                    SKAction.rotate(byAngle: 0.02, duration: 2.0),
                    SKAction.rotate(byAngle: -0.04, duration: 4.0),
                    SKAction.rotate(byAngle: 0.02, duration: 2.0)
                ])
                body.run(SKAction.repeatForever(tiltSeq), withKey: "headTilt")
            }
        } else {
            body.removeAction(forKey: "headTilt")
            body.zRotation = 0 // Reset to upright
        }
    }

    func setSwaying(enabled: Bool) {
        guard body != nil else { return }
        isSwaying = enabled
        let key = "swaying"
        
        if enabled {
            // Define sway action
            let swayLeft = SKAction.rotate(byAngle: 0.03, duration: 2.2)
            let swayRight = SKAction.rotate(byAngle: -0.06, duration: 4.4)
            let swayBack = SKAction.rotate(byAngle: 0.03, duration: 2.2)
            let swaySeq = SKAction.sequence([swayLeft, swayRight, swayBack])
            let swayAction = SKAction.repeatForever(swaySeq)
            
            if hairOverlay.action(forKey: key) == nil {
                hairOverlay.run(swayAction, withKey: key)
            }
            if hairBase.action(forKey: key) == nil && !hairBase.isHidden {
                hairBase.run(swayAction, withKey: key)
            }
            if scarfFront.action(forKey: key) == nil {
                scarfFront.run(swayAction, withKey: key)
            }
            if scarfBack.action(forKey: key) == nil {
                scarfBack.run(swayAction, withKey: key)
            }
        } else {
            hairOverlay.removeAction(forKey: key)
            hairBase.removeAction(forKey: key)
            scarfFront.removeAction(forKey: key)
            scarfBack.removeAction(forKey: key)
            
            hairOverlay.zRotation = 0
            hairBase.zRotation = 0
            scarfFront.zRotation = 0
            scarfBack.zRotation = 0
        }
    }

    func setBlinking(enabled: Bool) {
        guard eyes != nil else { return }
        isBlinking = enabled
        let key = "blinking"
        
        if enabled {
            if eyes.action(forKey: key) == nil {
                let openTex = SKTexture(imageNamed: "eye_open")
                let halfTex = SKTexture(imageNamed: "eye_half")
                let closeTex = SKTexture(imageNamed: "eye_close")
                
                let blinkAnim = SKAction.animate(with: [halfTex, closeTex, halfTex, openTex], timePerFrame: 0.05)
                
                let sequence = SKAction.sequence([blinkAnim, SKAction.wait(forDuration: 4.0)])
                
                eyes.run(SKAction.repeatForever(sequence), withKey: key)
            }
        } else {
            eyes.removeAction(forKey: key)
            eyes.texture = SKTexture(imageNamed: "eye_open")
        }
    }
}
