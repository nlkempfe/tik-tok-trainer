//
//  HistoryDetailView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 4/5/21.
//

import Foundation
import SwiftUI

struct HistoryDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    var result: StoredResult

    var playbackView: some View {
        HStack(spacing: 0) {
            LoopingPlayer(url: result.tutorial!, playbackRate: 1.0, isUploadedVideo: true)
            LoopingPlayer(url: result.recording!, playbackRate: 1.0, isUploadedVideo: false)
        }
        .zIndex(1.0)
    }
    
    var discardButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }, label: {
            Image(systemName: "xmark")
                .foregroundColor(.black)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    var background: some View {
        Rectangle()
            .fill()
            .ignoresSafeArea(.all)
            .background(Color.white)
            .foregroundColor(Color.white)
    }

    var body: some View {
            ZStack {
                background
                VStack(alignment: .leading) {
                discardButton
                    .padding(.top, 50)
                    .zIndex(2.0)
                VStack(spacing: 10) {
                    Text("Results")
                        .font(.title)
                    Text(result.timestamp ?? Date.init(), style: .date).foregroundColor(Color.black).bold() + Text(" ").foregroundColor(Color.black) + Text(result.timestamp ?? Date.init(), style: .time).bold()
                        .foregroundColor(Color.black)
                    playbackView
                    .scaleEffect(x: 0.90, y: 0.90)
                    VStack {
                        Text("Score: \(result.score * 100)%")
                        .padding(.bottom, 10)
                        .foregroundColor(Color.black)
                    Text("Mistakes: MISTAKES")
                        .padding(.bottom, 10)
                        .foregroundColor(Color.black)
                        Text("Duration: \(result.duration) seconds")
                        .foregroundColor(Color.black)
                        .padding(.bottom, 20)
                    }
                    .padding(.bottom, 30)
                }
                .background(Color.white)
            }
        }
    }

}
