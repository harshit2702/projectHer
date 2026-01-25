//
//  Avatar+Wind.swift
//  projectHer
//
//  Created by Harshit Agarwal on 25/01/26.
//

import SpriteKit

// --- Wind Lab Extensions ---
struct WindStep {
    var asset: String
    var duration: Double
}

extension AvatarScene {
    // --- Wind Variations (Looping) ---
    func stopWind() {
        guard hairOverlay != nil else { return }
        activeWind = nil
        hairOverlay.removeAction(forKey: "wind")
        hairOverlay.zRotation = 0
        hairOverlay.isHidden = true // Hide animation layer
        hairBase?.isHidden = false   // Restore base layer
    }

    func startWindVar1() {
        guard hairFront != nil else { return }
        stopWind() // Reset first
        activeWind = "wind1"
        
        hairFront.isHidden = false
        hairBase?.isHidden = true // A: Hide base hair
        
        // Sequence A: hair_2, 3, 2, 2, 3, hair, 3, 2
        let textures = ["hair_2", "hair_3", "hair_2", "hair_2", "hair_3", "hair", "hair_3", "hair_2"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWindVar2() {
        guard hairFront != nil else { return }
        stopWind()
        activeWind = "wind2"
        
        hairFront.isHidden = false
        hairBase?.isHidden = true // B: Hide base hair
        
        // Sequence B: hair_2, 3, 2
        let textures = ["hair_2", "hair_3", "hair_2"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWindVar3() {
        guard hairFront != nil else { return }
        stopWind()
        activeWind = "wind3"
        
        setBaseHair("hat_1") // C: Force Base to Hat 1
        hairFront.isHidden = false
        hairBase?.isHidden = false
        
        // Sequence C (Base hat_1): hair_4, 2, 4, 3, 4
        let textures = ["hair_4", "hair_2", "hair_4", "hair_3", "hair_4"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWindVar4() {
        guard hairFront != nil else { return }
        stopWind()
        activeWind = "wind4"
        
        setBaseHair("winter_hat_motion_wind") // D: Force Base to Winter Hat Motion
        hairFront.isHidden = false
        hairBase?.isHidden = false
        
        // Sequence D (Base WindHatMotionWind): hair_2, 3, winter_hat, 2
        let textures = ["hair_2", "hair_3", "winter_hat", "hair_2"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWindVar5() {
        guard hairFront != nil else { return }
        stopWind()
        activeWind = "wind5"
        
        setBaseHair("winter_hat") // E: Force Base to Winter Hat
        hairFront.isHidden = false
        hairBase?.isHidden = false
        
        // Sequence E (Base winter_hat): hair_2, 3, 2
        let textures = ["hair_2", "hair_3", "hair_2"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWindVar6() {
        guard hairFront != nil else { return }
        stopWind()
        activeWind = "wind6"
        
        setBaseHair("winter_hat") // F: Force Base to Winter Hat
        hairFront.isHidden = false
        hairBase?.isHidden = false
        
        // Sequence F: hair, winter_hat, hair
        let textures = ["hair", "winter_hat", "hair"].map { SKTexture(imageNamed: $0) }
        runWindSequence(textures)
    }
    
    func startWinterHatWind() {
        startWindVar6()
    }
    
    private func runWindSequence(_ textures: [SKTexture]) {
        var actions: [SKAction] = []
        for tex in textures {
            actions.append(SKAction.setTexture(tex))
            actions.append(SKAction.wait(forDuration: 0.8))
        }
        hairFront.run(SKAction.repeatForever(SKAction.sequence(actions)), withKey: "wind")
    }
    
    // --- Custom Wind Helpers ---
    
    func isHatAsset(_ name: String) -> Bool {
        return name.hasPrefix("hat_") || name.hasPrefix("winter_hat")
    }

    func setBaseHair(_ name: String) {
        guard hairBase != nil else { return }
        AvatarScene._baseHairName = name
        if name == "none" {
            hairBase.isHidden = true
            return
        }
        hairBase.isHidden = false
        hairBase.texture = SKTexture(imageNamed: name)
        // Hat above (32), hair below (29) overlay (31)
        hairBase.zPosition = isHatAsset(name) ? 32 : 29
    }
    
    func startCustomWind(steps: [WindStep], loop: Bool) {
        stopWind()
        
        guard hairOverlay != nil else { return }
        hairOverlay.isHidden = false // Unhide for custom wind

        // Filter valid steps
        let validSteps = steps.filter { $0.asset != "none" && $0.duration > 0 }
        guard !validSteps.isEmpty else { return }

        var actions: [SKAction] = []
        for s in validSteps {
            actions.append(SKAction.setTexture(SKTexture(imageNamed: s.asset)))
            actions.append(SKAction.wait(forDuration: s.duration))
        }

        let seq = SKAction.sequence(actions)
        hairOverlay.run(loop ? SKAction.repeatForever(seq) : seq, withKey: "wind")
    }
}
