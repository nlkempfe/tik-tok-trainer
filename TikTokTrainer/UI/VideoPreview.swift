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
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        playerItem = AVPlayerItem(url: videoURL!)
        player = AVQueuePlayer(items: [playerItem])
        player.actionAtItemEnd = .none
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        print(playerLooper.loopCount)

        controller.player = player
        controller.modalPresentationStyle = .overCurrentContext
        controller.showsPlaybackControls = false
        controller.player?.play()
        NotificationCenter.default.addObserver(self,
                                               selector: Selector(("playerItemDidReachEnd:")),
                                                         name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                         object: player.currentItem)
        return controller
    }

    func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
        // playerItemDidReachEnd(notification: <#T##Notification#>)
    }

    @objc func playerItemDidReachEnd(notification: Notification) {
        print("test")
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: CMTime.zero, completionHandler: nil)
        }
    }

}
