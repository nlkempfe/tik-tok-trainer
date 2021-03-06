//
//  VideoPreview.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 2/18/21.
//

import Foundation
import AVFoundation
import SwiftUI
import AVKit

struct LoopingPlayer: UIViewRepresentable {
    var url: URL
    var playbackRate: Double
    var isUploadedVideo: Bool

    func makeUIView(context: Context) -> some UIView {
        return QueuePlayerUIView(frame: .zero, videoURL: url, playbackRate: playbackRate, isUploadedVideo: isUploadedVideo)
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        // leave this empty
    }
}

struct VideoPlayerView: UIViewRepresentable {
    var url: URL
    var playbackRate: Double

    func makeUIView(context: Context) -> some UIView {
        return PlayerUIView(frame: .zero, videoURL: url, playbackRate: playbackRate)
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        // leave this empty
    }
}

class QueuePlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    init(frame: CGRect, videoURL: URL, playbackRate: Double, isUploadedVideo: Bool) {
        super.init(frame: frame)

        let playerItem = AVPlayerItem(url: videoURL)

        let player = AVQueuePlayer(playerItem: playerItem)
        playerLayer.player = player
        layer.addSublayer(playerLayer)

        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        player.play()
        if isUploadedVideo {
            player.rate = Float(playbackRate)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var player: AVPlayer?

    init(frame: CGRect, videoURL: URL, playbackRate: Double) {
        super.init(frame: frame)

        let playerItem = AVPlayerItem(url: videoURL)

        player = AVPlayer(playerItem: playerItem)
        playerLayer.player = player
        layer.addSublayer(playerLayer)

        player?.play()
        player?.rate = Float(playbackRate)
    }

    func playVideo() {
        player?.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ProgressBar: UIViewRepresentable {
    var duration: Double = 0.0
    var progressBar = UIProgressView()

    func makeUIView(context: Context) -> some UIView {
        DispatchQueue.main.async {
            UIView.animate(withDuration: self.duration) {
                progressBar.setProgress(1.0, animated: true)
            }
        }
        return progressBar
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // leave empty
    }
}
