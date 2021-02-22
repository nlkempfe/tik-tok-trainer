//
//  TikTokTrainerApp.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 1/13/21.
//

import SwiftUI
import Promises

@main
struct TikTokTrainerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    /// Runs the poseNetProcessor on the uploaded videos
    /// Runs the two different run functions concurrently with promises
    init() {
        all(
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "preRecordedVid", withExtension: "mp4")!),
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "recordedVid", withExtension: "mp4")!)
        ).then { movieOne, movieTwo in
            let error = try ScoringFunction(preRecordedVid: movieOne, recordedVid: movieTwo).computeUnweightedMSE()
            print(error)
        }.catch { error in
            print("Error: \(error)")
        }
    }
}
