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
    init() {
        var preRecordedVid = PoseNetProcessor.run(url: Bundle.main.url(forResource: "workout", withExtension: "mp4")!)
        var recordedVid = PoseNetProcessor.run(url: Bundle.main.url(forResource: "f", withExtension: "mov")!)
        var function = ScoringFunction()
        preRecordedVid.then { vid in
            function.preRecordedVid = vid
            recordedVid.then { vid in
                function.recordedVid = vid
                var score = function.computeScore()
                score.then { score in
                    print("score: " + score.description)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
