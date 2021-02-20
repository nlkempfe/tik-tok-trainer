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

public var videoURL: URL!

struct LoopingPlayer: UIViewRepresentable {
    var url: URL!

    func makeUIView(context: Context) -> some UIView {
        videoURL = url
        return QueuePlayerUIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        // leave this empty
    }
}

class QueuePlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let playerItem = AVPlayerItem(url: videoURL)

        let player = AVQueuePlayer(playerItem: playerItem)
        playerLayer.player = player
        layer.addSublayer(playerLayer)

        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)

        player.play()
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
        print(duration)
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
