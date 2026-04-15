//
//  PiPManager.swift
//  projectHer
//
//  Picture-in-Picture manager with animated avatar mouth for video calls.
//  Composites outfit + mouth frames and cycles them when TTS is speaking.
//

import AVKit
import UIKit
import Combine

@MainActor
class PiPManager: NSObject, ObservableObject {
    static let shared = PiPManager()
    
    // MARK: - Published State
    @Published var isPiPActive = false
    @Published var isPiPPossible = false
    
    // MARK: - PiP Components
    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var pipContentSource: AVPictureInPictureController.ContentSource?
    
    // MARK: - Animation State
    private var animationTimer: Timer?
    private var isTalking = false
    private var currentMouthFrame = 0
    private let mouthFrameNames = ["mouth_neutral", "mouth_ah", "mouth_open", "mouth_ah"]
    private var currentOutfitId: String = "avatar_outfit_hoodie_black"
    
    // MARK: - Cached Images
    private var cachedCompositeFrames: [UIImage] = []
    private var staticFrame: UIImage?
    
    // MARK: - Background Layer View
    private var containerView: UIView?
    
    override init() {
        super.init()
        setupPiP()
    }
    
    // MARK: - Setup
    
    private func setupPiP() {
        // Create sample buffer display layer
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer?.videoGravity = .resizeAspect
        sampleBufferDisplayLayer?.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        
        // Create a container view to hold the layer
        containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        if let layer = sampleBufferDisplayLayer {
            containerView?.layer.addSublayer(layer)
        }
        
        // Create content source for PiP
        guard let displayLayer = sampleBufferDisplayLayer else { return }
        
        pipContentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        
        guard let contentSource = pipContentSource else { return }
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        
        // Check if PiP is supported
        isPiPPossible = AVPictureInPictureController.isPictureInPictureSupported()
        
        print("📺 PiP Manager initialized. Supported: \(isPiPPossible)")
    }
    
    // MARK: - Public API
    
    /// Update the current outfit for PiP display
    func setOutfit(_ outfitId: String) {
        let fullOutfitId = outfitId.hasPrefix("avatar_outfit_") ? outfitId : "avatar_outfit_\(outfitId)"
        if currentOutfitId != fullOutfitId {
            currentOutfitId = fullOutfitId
            rebuildCachedFrames()
        }
    }
    
    /// Set talking state to animate mouth
    func setTalking(_ talking: Bool) {
        if isTalking != talking {
            isTalking = talking
            if talking {
                startMouthAnimation()
            } else {
                stopMouthAnimation()
                displayStaticFrame()
            }
        }
    }
    
    /// Start PiP mode
    func startPiP() {
        guard isPiPPossible, let controller = pipController else {
            print("⚠️ PiP not available")
            return
        }
        
        // Rebuild frames for current outfit
        rebuildCachedFrames()
        displayStaticFrame()
        
        if !controller.isPictureInPictureActive {
            controller.startPictureInPicture()
            print("📺 Starting PiP")
        }
    }
    
    /// Stop PiP mode
    func stopPiP() {
        guard let controller = pipController else { return }
        
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
            print("📺 Stopping PiP")
        }
        
        stopMouthAnimation()
    }
    
    // MARK: - Frame Compositing
    
    /// Rebuild cached composite frames (outfit + mouth states)
    private func rebuildCachedFrames() {
        cachedCompositeFrames.removeAll()
        
        // Load outfit base image
        guard let outfitImage = UIImage(named: currentOutfitId) else {
            print("⚠️ Could not load outfit: \(currentOutfitId)")
            return
        }
        
        // Composite each mouth frame with the outfit
        for mouthName in mouthFrameNames {
            if let mouthImage = UIImage(named: mouthName) {
                let composite = compositeImages(base: outfitImage, overlay: mouthImage)
                cachedCompositeFrames.append(composite)
            }
        }
        
        // Static frame is mouth neutral
        if let neutralMouth = UIImage(named: "mouth_neutral") {
            staticFrame = compositeImages(base: outfitImage, overlay: neutralMouth)
        } else {
            staticFrame = outfitImage
        }
        
        print("📺 Cached \(cachedCompositeFrames.count) PiP frames for \(currentOutfitId)")
    }
    
    /// Composite two images (overlay on base)
    private func compositeImages(base: UIImage, overlay: UIImage) -> UIImage {
        let size = base.size
        
        UIGraphicsBeginImageContextWithOptions(size, false, base.scale)
        defer { UIGraphicsEndImageContext() }
        
        base.draw(in: CGRect(origin: .zero, size: size))
        
        // Draw mouth overlay - centered horizontally, positioned for face
        // Adjust these values based on your avatar's face position
        let mouthSize = overlay.size
        let mouthX = (size.width - mouthSize.width) / 2
        let mouthY = size.height * 0.42  // Adjust based on your avatar
        
        overlay.draw(in: CGRect(x: mouthX, y: mouthY, width: mouthSize.width, height: mouthSize.height))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? base
    }
    
    // MARK: - Animation
    
    private func startMouthAnimation() {
        animationTimer?.invalidate()
        currentMouthFrame = 0
        
        // Animate at ~6fps for natural talking
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMouthFrame()
            }
        }
    }
    
    private func stopMouthAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentMouthFrame = 0
    }
    
    private func advanceMouthFrame() {
        guard !cachedCompositeFrames.isEmpty else { return }
        
        currentMouthFrame = (currentMouthFrame + 1) % cachedCompositeFrames.count
        let frame = cachedCompositeFrames[currentMouthFrame]
        displayImage(frame)
    }
    
    private func displayStaticFrame() {
        if let frame = staticFrame {
            displayImage(frame)
        }
    }
    
    // MARK: - Sample Buffer Display
    
    private func displayImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        // Create pixel buffer from image
        guard let pixelBuffer = createPixelBuffer(from: cgImage) else { return }
        
        // Create sample buffer
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let format = formatDescription else { return }
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: Int64(CACurrentMediaTime() * 1000), timescale: 1000),
            decodeTimeStamp: .invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if let buffer = sampleBuffer {
            sampleBufferDisplayLayer?.enqueue(buffer)
        }
    }
    
    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in
            print("📺 PiP will start")
        }
    }
    
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in
            self.isPiPActive = true
            print("📺 PiP started")
        }
    }
    
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in
            self.isPiPActive = false
            self.stopMouthAnimation()
            print("📺 PiP stopped")
        }
    }
    
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in
            print("⚠️ PiP failed to start: \(error)")
        }
    }
    
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            // Here we would restore the full AvatarView
            print("📺 Restoring from PiP")
            completionHandler(true)
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        // Called when play/pause is toggled in PiP
        Task { @MainActor in
            print("📺 PiP setPlaying: \(playing)")
        }
    }
    
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        // Return infinite time range since this is a "live" feed
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        return false
    }
    
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        Task { @MainActor in
            print("📺 PiP render size: \(newRenderSize.width)x\(newRenderSize.height)")
        }
    }
    
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping () -> Void) {
        // Not applicable for live avatar content - just call completion immediately
        completion()
    }
}

