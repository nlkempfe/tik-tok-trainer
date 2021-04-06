//
//  SelectedVideo.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 4/5/21.
//

import Foundation
import UIKit

/// Holds all the information about a video the user selects to compare to their movements
struct SelectedVideo {
    /// The permanent location to the video
    let videoURL: URL
    /// A smaller thumbnail of the video
    let thumbnail: UIImage
    /// The total length of the video
    let videoDuration: Double
    /// Playback rate
    var playbackRate: Double = 1.0
}
