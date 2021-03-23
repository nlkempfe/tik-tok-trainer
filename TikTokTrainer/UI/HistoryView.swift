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
        entity: StoredVideo.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \StoredVideo.storedDateTime, ascending: true)
        ]
    ) var videos: FetchedResults<StoredVideo>

    var body: some View {
        List(videos, id: \.self) { (video: StoredVideo) in
            Text(video.location?.absoluteString ?? "not found")
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
