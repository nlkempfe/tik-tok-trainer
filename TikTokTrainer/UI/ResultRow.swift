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
        HStack {
            playbackView
            VStack(alignment: .leading) {
                Text("Resulted: ").foregroundColor(Color.black) + Text(result.timestamp ?? Date.init(), style: .date).foregroundColor(Color.black) + Text(" ").foregroundColor(Color.black) + Text(result.timestamp ?? Date.init(), style: .time)
                    .foregroundColor(Color.black)
                Text("Score: \(result.score * 100)%")
                    .foregroundColor(Color.black)
                Text("Recording: \(result.recording!.absoluteString)")
                    .foregroundColor(Color.black)
                Text("Tutorial: \(result.tutorial!.absoluteString)")
                    .foregroundColor(Color.black)
            }
        }
    }
}
