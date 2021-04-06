//
//  DataController.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 3/2/21.
//

import Foundation
import CoreData

struct DataController {
    static let containerName = "ProcessedVideoModel"
    static let shared = DataController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: DataController.containerName)

        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Could not load CoreData. Error: \(error.localizedDescription)")
            }
        })
    }

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Could not save core data. Error: \(error.localizedDescription)")
            }
        }
    }
}
