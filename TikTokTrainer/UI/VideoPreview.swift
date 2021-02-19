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

class PlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        print("init")

        let player = AVPlayer(url: videoURL)
        playerLayer.player = player

        layer.addSublayer(playerLayer)

        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(self, selector: #selector(rewindVideo(notification:)), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    @objc
    func rewindVideo(notification: Notification) {
        playerLayer.player?.seek(to: .zero)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

class QueuePlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Load Video
//        let fileUrl = Bundle.main.url(forResource: "moon", withExtension: "mp4")!
//        let playerItem = AVPlayerItem(url: fileUrl)

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

// final class PlayerViewController: UIViewControllerRepresentable {
//
//    var videoURL: URL?
//    var player: AVPlayer!
//    var playerLayer: AVPlayerLayer!
//    var playerItem: AVPlayerItem!
//    var playerLooper: AVPlayerLooper!
//    var controller = AVPlayerViewController()
//
//
//    init(videoURL: URL) {
//        self.videoURL = videoURL
//        player = AVPlayer(url: self.videoURL!)
//        player.actionAtItemEnd = .none
//
//        let duration = Int64( ( (Float64(CMTimeGetSeconds(AVAsset(url: videoURL).duration)) *  10.0) - 1) / 10.0 )
//       playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
//
//        controller.player = player
//        controller.modalPresentationStyle = .overCurrentContext
//        controller.showsPlaybackControls = false
//        controller.player?.play()
//
//        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { _ in
//            self.player?.seek(to: CMTime.zero)
//            //self.player?.play()
//            print("ok")
//        }
//    }
//
//    func makeUIViewController(context: Context) -> AVPlayerViewController {
//
//        print("here")
//        return controller
//    }
//
//    func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
//        // leave empty for now
//    }
//
//    @objc func playerDidFinishPlaying(notification: Notification) {
//        print("test")
//        if let playerItem = notification.object as? AVPlayerItem {
//            playerItem.seek(to: CMTimeMake(value: Int64(0.5), timescale: 1), completionHandler: nil)
//        }
//    }
//
// }
