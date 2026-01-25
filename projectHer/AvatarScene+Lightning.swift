//
//  AvatarScene+Lightning.swift
//  projectHer
//
//  Created by Harshit Agarwal on 25/01/26.
//

import SpriteKit

extension AvatarScene {
    var timeOfDay: CGFloat {
        get { AvatarScene.lightingTime }
        set { setTimeOfDay(newValue) }
    }

    private static var lightingTime: CGFloat = 8

    func configureLighting() {
        guard let body = body else { return }
        self.lighting = LightingController(scene: self, puppet: body)
        self.lighting?.update(timeOfDay: AvatarScene.lightingTime)
    }

    func setTimeOfDay(_ hours: CGFloat) {
        AvatarScene.lightingTime = hours
        self.lighting?.update(timeOfDay: hours)
    }
}
