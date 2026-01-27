import SpriteKit
import UIKit

extension AvatarScene {
    
    // MARK: - Touch Handlers
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1. Pinch Start Check (2 fingers)
        if let event = event, let allTouches = event.allTouches, allTouches.count == 2 {
            let touchesArray = Array(allTouches)
            let t1 = touchesArray[0]
            let t2 = touchesArray[1]
            
            let p1 = t1.location(in: self)
            let p2 = t2.location(in: self)
            
            pinchStartDistance = hypot(p1.x - p2.x, p1.y - p2.y)
            isPinching = true
            
            // Determine "Center" of pinch to guess body part
            let center = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
            detectBodyPart(at: center)
            print("✌️ Potential Pinch detected on: \(detectedPart ?? "None")")
            return
        }
        
        // 2. Single Touch Tracking
        guard let touch = touches.first, activeTouch == nil else { return }
        
        activeTouch = touch
        touchStartLocation = touch.location(in: self)
        touchStartTime = touch.timestamp
        detectedPart = nil // Reset
        isPinching = false
        
        detectBodyPart(at: touchStartLocation)
        
        if let part = detectedPart {
            print("👇 Start tracking on: \(part)")
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Pinch Logic
        if isPinching, let event = event, let allTouches = event.allTouches, allTouches.count == 2 {
            let touchesArray = Array(allTouches)
            let p1 = touchesArray[0].location(in: self)
            let p2 = touchesArray[1].location(in: self)
            
            let currentDistance = hypot(p1.x - p2.x, p1.y - p2.y)
            let delta = pinchStartDistance - currentDistance
            
            // Check if fingers moved closer (closing pinch)
            if delta > pinchThreshold {
                if let part = detectedPart {
                    let intensity = classifyPinch(delta: delta)
                    triggerGesture(part: part, type: "Pinch", intensity: intensity)
                    isPinching = false // Prevent duplicate triggers for same gesture
                }
            }
            return
        }
        
        guard let touch = touches.first, touch == activeTouch else { return }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPinching {
            isPinching = false
            return
        }
        
        guard let touch = touches.first, touch == activeTouch, let part = detectedPart else {
            resetTouch()
            return
        }
        
        let endLocation = touch.location(in: self)
        
        // Standard Gesture Logic
        let dx = endLocation.x - touchStartLocation.x
        let dy = endLocation.y - touchStartLocation.y
        let distance = hypot(dx, dy)
        let duration = touch.timestamp - touchStartTime
        
        var gesture = ""
        var intensity: GestureIntensity = .moderate
        
        if distance > slideThreshold {
            if part == "Hair" {
                // Determine Pull Direction
                if abs(dx) > abs(dy) {
                    gesture = dx > 0 ? "Pull Right" : "Pull Left"
                } else {
                    gesture = dy > 0 ? "Pull Up" : "Pull Down"
                }
            } else {
                gesture = "Slide"
            }
        } else if duration > longPressTime {
            // Disable Long Press for Cheeks as requested
            if part == "Cheeks" {
                gesture = "Tap" // Fallback to Tap or ignore
            } else {
                gesture = "Long Press"
                intensity = classifyLongPress(duration: duration)
            }
        } else {
            gesture = "Tap"
        }
        
        triggerGesture(part: part, type: gesture, intensity: intensity)
        resetTouch()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetTouch()
    }
    
    func resetTouch() {
        activeTouch = nil
        detectedPart = nil
    }
    
    // MARK: - Gesture Logic
    func triggerGesture(part: String, type: String, intensity: GestureIntensity = .moderate) {
        print("✨ Gesture: \(type) on \(part) [\(intensity.rawValue)]")
        
        // Get the base gesture type for server (Pull Left/Right/Up/Down -> Pull)
        let baseGesture = type.hasPrefix("Pull") ? "Pull" : type
        
        // Send to Server for context-aware reaction
        Task {
            do {
                let response = try await NetworkManager.shared.recordInteraction(
                    part: part,
                    gesture: baseGesture,
                    intensity: intensity.rawValue,
                    isTalking: self.isTalking
                )
                
                await MainActor.run {
                    // 1. Play the server-determined reaction animation
                    self.playReaction(reactionId: response.reaction_id, spawnHearts: response.spawn_hearts)
                    
                    // 2. Update hair state
                    let assetName = (response.hair_state == "hair_neat") ? "hair" : response.hair_state
                    self.hairBase?.texture = SKTexture(imageNamed: assetName)
                    
                    // 3. Show dialogue (silent mode = floating text, speak mode = TTS)
                    if let dialogue = response.dialogue {
                        self.showTouchDialogue(
                            text: dialogue,
                            mode: response.dialogue_mode,
                            emotion: response.dialogue_emotion ?? "neutral"
                        )
                    }
                    
                    // 4. Trigger haptic based on outcome
                    switch response.outcome {
                    case "positive":
                        self.triggerHaptic(type: "success")
                    case "negative":
                        self.triggerHaptic(type: "warning")
                    default:
                        self.triggerHaptic(type: "light")
                    }
                    
                    print("🎭 Reaction: \(response.reaction_id) [\(response.outcome)] | Bonding: \(response.bonding_score)")
                }
                
            } catch {
                print("❌ Failed to record interaction: \(error)")
                // Fallback to local reaction if server fails
                await MainActor.run {
                    self.handleReactionFallback(part: part, type: type, intensity: intensity)
                }
            }
        }
        
        onGestureDetected?(part, type)
        // Note: Reaction is now handled by server response, not locally
        // handleReaction is only used as fallback when server is unreachable
    }
    
    // MARK: - Dialogue Display
    
    /// Shows touch dialogue as floating text or triggers TTS
    func showTouchDialogue(text: String, mode: String, emotion: String) {
        // Always show floating text so user sees it
        showFloatingText(text)
        
        if mode == "speak" {
            // Trigger TTS via callback (connected to TTSManager in AvatarView)
            // This will also trigger lip sync via onChange(of: tts.isSpeaking)
            onSpeakDialogue?(text, emotion)
        }
    }
    
    /// Shows floating text above the avatar that fades out
    func showFloatingText(_ text: String) {
        // Remove any existing dialogue
        childNode(withName: "touchDialogue")?.removeFromParent()
        
        let label = SKLabelNode(text: text)
        label.name = "touchDialogue"
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 18
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: (body?.position.y ?? 0) + 180)
        label.zPosition = 300
        label.alpha = 0
        
        // Add background for readability
        let background = SKShapeNode(rectOf: CGSize(width: label.frame.width + 20, height: label.frame.height + 10), cornerRadius: 8)
        background.fillColor = UIColor.black.withAlphaComponent(0.6)
        background.strokeColor = .clear
        background.position = CGPoint(x: 0, y: -2)
        background.zPosition = -1
        label.addChild(background)
        
        addChild(label)
        
        // Animate: fade in, float up, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let floatUp = SKAction.moveBy(x: 0, y: 30, duration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        
        let sequence = SKAction.sequence([
            fadeIn,
            SKAction.group([floatUp, SKAction.sequence([SKAction.wait(forDuration: 1.5), fadeOut])]),
            remove
        ])
        
        label.run(sequence)
    }
    
    // MARK: - Fallback Reaction (when server unreachable)
    
    /// Local fallback reactions when server is unavailable
    func handleReactionFallback(part: String, type: String, intensity: GestureIntensity) {
        triggerHaptic(type: "medium")
        handleReaction(part: part, type: type, intensity: intensity)
    }
    
    // MARK: - Detection Helpers
    func detectBodyPart(at location: CGPoint) {
        // Check Mouth First (Explicit Debug Box)
        let bodyLoc = convert(location, to: body)
        if mouthHighlight.contains(bodyLoc) {
            detectedPart = "Mouth"
        }
        // Check masks in visual priority order
        else if checkMaskHit(node: noseMask, location: location) {
            detectedPart = "Nose"
        }
        else if checkMaskHit(node: cheeksMask, location: location) {
            detectedPart = "Cheeks"
        }
        else if checkMaskHit(node: earMask, location: location) {
            detectedPart = "Ears"
        }
        else if checkMaskHit(node: neckMask, location: location) {
            detectedPart = "Neck"
        }
        else if checkMaskHit(node: shoulderMask, location: location) {
            detectedPart = "Shoulders"
        }
        else if checkMaskHit(node: hairBase, location: location) {
            detectedPart = "Hair"
        }
    }
    
    func checkMaskHit(node: SKSpriteNode, location: CGPoint) -> Bool {
        // 1. Basic bounding box check (optimization)
        guard node.contains(location) else { return false }
        
        // 2. Get Texture Data
        guard let texture = node.texture else { return false }
        
        // 3. Convert to local node coordinates
        let localPos = convert(location, to: node)
        let size = node.size
        
        // 4. Calculate pixel coordinates on the texture
        // Origin of texture is bottom-left, localPos is center-relative
        let normalizedX = (localPos.x / size.width) + 0.5
        let normalizedY = (localPos.y / size.height) + 0.5
        
        // Helper to get alpha from texture
        let cgImage = texture.cgImage()
        
        let width = cgImage.width
        let height = cgImage.height
        
        let x = Int(normalizedX * CGFloat(width))
        let y = Int(normalizedY * CGFloat(height))
        
        // Check bounds
        guard x >= 0 && x < width && y >= 0 && y < height else { return false }
        
        // 5. Check Alpha
        return isPixelOpaque(cgImage: cgImage, x: x, y: y)
    }
    
    private func isPixelOpaque(cgImage: CGImage, x: Int, y: Int) -> Bool {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let _ = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // Calculate offset
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        
        // Check if offset is within data bounds (safe check)
        if offset < 0 || offset >= CFDataGetLength(data) { return false }
        
        let alphaInfo = cgImage.alphaInfo
        
        if alphaInfo == .none || alphaInfo == .noneSkipLast || alphaInfo == .noneSkipFirst {
            return true // No alpha channel = opaque
        }
        
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixel,
                                width: 1,
                                height: 1,
                                bitsPerComponent: 8,
                                bytesPerRow: 4,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        // Translate to draw the specific pixel at (0,0)
        context?.translateBy(x: CGFloat(-x), y: CGFloat(-y))
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        // Check Alpha (pixel[3])
        return pixel[3] > 20 // Threshold (0-255)
    }
}
