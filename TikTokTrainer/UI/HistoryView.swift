//
//  HistoryView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 3/2/21.
//

import SwiftUI

struct HistoryView: View {

    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(
        entity: StoredResult.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \StoredResult.timestamp, ascending: true)
        ]
    ) var results: FetchedResults<StoredResult>

    var body: some View {
//        List(videos, id: \.self) { (video: StoredVideo) in
//            Text(video.location?.absoluteString ?? "not found")
//        }
        List(results, id: \.self) { (result: StoredResult) in
            Text("Video")
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
