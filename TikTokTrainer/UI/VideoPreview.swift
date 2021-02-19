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

final class PlayerViewController: UIViewControllerRepresentable {

    var videoURL: URL?
    var player: AVQueuePlayer!
    var playerLayer: AVPlayerLayer!
    var playerItem: AVPlayerItem!
    var playerLooper: AVPlayerLooper!
    var controller = AVPlayerViewController()

    init(videoURL: URL) {
        self.videoURL = videoURL
        playerItem = AVPlayerItem(url: self.videoURL!)
        player = AVQueuePlayer(items: [playerItem])
        player.actionAtItemEnd = .none
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        print("init")

        controller.player = player
        controller.modalPresentationStyle = .overCurrentContext
        controller.showsPlaybackControls = false
        controller.player?.play()
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        
        print("here")
        return controller
    }

    func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
        // leave empty for now
    }

    @objc func playerDidFinishPlaying(notification: Notification) {
        print("test")
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: CMTime.zero, completionHandler: nil)
        }
    }

}
