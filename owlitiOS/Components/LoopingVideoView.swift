//
//  LoopingVideoView.swift
//  owlitiOS
//
//  Created by Assistant on 09/01/2026.
//

import SwiftUI
import AVFoundation

struct LoopingVideoView: UIViewRepresentable {
    var videoName: String
    var videoExtension: String = "mp4"
    
    func makeUIView(context: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName, videoExtension: videoExtension)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed for static video parameter
    }
}

class LoopingPlayerUIView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    
    private let videoName: String
    private let videoExtension: String
    
    init(videoName: String, videoExtension: String) {
        self.videoName = videoName
        self.videoExtension = videoExtension
        super.init(frame: .zero)
        
        setupPlayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPlayer() {
        // Load the video from the bundle
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("❌ LoopingVideoView: Could not find video named \(videoName).\(videoExtension)")
            return
        }
        
        // Create the player item
        let playerItem = AVPlayerItem(url: url)
        
        // Setup Queue Player & Looper
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true // Ensure silence as requested
        
        // Loop Logic
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        // Setup Layer
        let playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        
        self.queuePlayer = queuePlayer
        self.playerLayer = playerLayer
        
        // Start playing
        queuePlayer.play()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    // MARK: - Lifecycle Cleanup
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            // Appeared: Resume if paused
            if queuePlayer?.timeControlStatus == .paused {
                queuePlayer?.play()
            }
        } else {
            // Disappeared: Pause to save resources
            queuePlayer?.pause()
        }
    }
    
    deinit {
        // Explicit cleanup probably not fully necessary with ARC but good practice
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        playerLayer = nil
        playerLooper = nil
        print("♻️ LoopingPlayerUIView Deallocated")
    }
}
