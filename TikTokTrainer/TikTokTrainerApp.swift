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
}
