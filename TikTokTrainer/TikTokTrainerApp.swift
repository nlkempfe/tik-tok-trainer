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
    
    init() {
        all(
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "preRecordedVid", withExtension: "mp4")!),
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "recordedVid", withExtension: "mp4")!)
        ).then { movieOne, movieTwo in
            ScoringFunction(preRecordedVid: movieOne, recordedVid: movieTwo).computeScore(callback: { result in
                print(result)
            })
        }.catch { error in
            print("Error: \(error)")
        }
    }
}
