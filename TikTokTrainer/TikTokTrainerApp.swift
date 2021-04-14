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

    let dataController = DataController.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }.onChange(of: scenePhase) { _ in
            dataController.save()
        }
    }
    
    init() {
        all(
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "TestDanceTrimmed", withExtension: ".mov")!),
            PoseNetProcessor.run(url: Bundle.main.url(forResource: "TrueDance", withExtension: ".mov")!)
        ).then { movieOne, movieTwo in
            return ScoringFunction(preRecordedVid: movieOne, recordedVid: movieTwo).computeScore()
        }
    }
}
