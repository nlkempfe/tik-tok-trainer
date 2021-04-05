//
//  ResultRow.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 3/29/21.
//

import Foundation
import SwiftUI

struct ResultRow: View {
    var result: StoredResult

    var playbackView: some View {
        HStack(spacing: 0) {
            LoopingPlayer(url: result.tutorial!, playbackRate: 1.0, isUploadedVideo: true)
            LoopingPlayer(url: result.recording!, playbackRate: 1.0, isUploadedVideo: false)
        }
        .zIndex(1.0)
    }

    var body: some View {
        HStack(spacing: 0) {
            playbackView
            VStack(alignment: .leading) {
                Text(result.timestamp ?? Date.init(), style: .date).foregroundColor(Color.black).bold() + Text(" ").foregroundColor(Color.black) + Text(result.timestamp ?? Date.init(), style: .time).bold()
                    .foregroundColor(Color.black)
                Text("Score: \(result.score * 100)%")
                    .foregroundColor(Color.black)
                Text("Duration: \(result.duration) seconds")
                    .foregroundColor(Color.black)
                Text("Mistakes: MISTAKES")
                    .foregroundColor(Color.black)
            }
        }
    }
}
