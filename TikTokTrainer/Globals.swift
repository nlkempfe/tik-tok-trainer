//
//  Globals.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 2/17/21.
//
import Foundation
import SwiftUI

struct NumConstants {
    static let yScale = CGFloat(0.5)
    static let yScaleLandscape = CGFloat(0.16)
    static let yCoordinateScale = CGFloat(1.25)
    static let xCoordinateScale = CGFloat(0.5)
    static let iconXScale = CGFloat(1.5)
    static let iconYScale = CGFloat(1.5)
    static let timerVal = 3
}

struct IconConstants {
    static let cameraOutline = "arrow.triangle.2.circlepath.camera"
    static let flash = "bolt"
    static let flashOn = "bolt.fill"
    static let uploadFile = "plus.square"
    static let uploadFileFilled = "plus.square.fill"
    static let speedometer = "speedometer"
}

struct StringConstants {
    static let uploadVideo = "Upload a video"
    static let permissionsCamera = "Enable camera access to continue"
    static let loadingTitle = "Let's see how you did"
    static let loadingSubtitle = "Analyzing dance..."
}
