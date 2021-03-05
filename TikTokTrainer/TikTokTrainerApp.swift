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
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "TrueDance", withExtension: "mov")!),
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "TestDanceTrimmed", withExtension: "mov")!)
        ).then { movieOne, movieTwo in
            ScoringFunction(preRecordedVid: movieOne, recordedVid: movieTwo).computeScore(callback: { result in
                print(result)
            })
        }.catch { error in
            print("Error: \(error)")
        }
    }
}
