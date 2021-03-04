//
//  PoseNetResult.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 2/13/21.
//

import Foundation
import Vision
import CoreGraphics

struct PoseNetResult {
    var points = [VNHumanBodyPoseObservation.JointName: CGPoint]()
    var imageSize: CGSize?
}
