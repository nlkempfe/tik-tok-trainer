//
//  ResultsView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 3/8/21.
//

import Foundation
import SwiftUI

struct ResultsView: View {
    var score: CGFloat
    var duration: Double
    var url: URL
    var playbackRate: Double

    var submitButton: some View {
        Button(action: {
            print("submit button pressed")
        }, label: {
            Text("Submit")
                .foregroundColor(.white)
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
        })
        .background(Color.blue)
        .cornerRadius(15)
    }

    var body: some View {
        VStack {
            LoopingPlayer(url: self.url, playbackRate: self.playbackRate, isUploadedVideo: false)
            Spacer()
            Text("Score: \(score)%")
                .padding(.bottom, 10)
            Text("Mistakes: MISTAKES")
                .padding(.bottom, 10)
            Text("Duration: \(Int(round(duration))) seconds")
            Spacer()
            submitButton
        }
        .background(Color.white)
    }
}
