//
//  ResultsView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 3/8/21.
//

import Foundation
import SwiftUI

struct ResultsView: View {
    @State var showDiscardAlert = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var managedObjectContext

    var score: Double
    var duration: Double
    var url: URL
    var playbackRate: Double

    func discard() {
        self.showDiscardAlert = false
        presentationMode.wrappedValue.dismiss()
    }

    func submit() {
        let dbResult = StoredResult(context: managedObjectContext)
        dbResult.timestamp = Date.init()
        dbResult.score = score.isNaN ? 0 : Double(score)
        DataController.shared.save()
    }

    var saveButton: some View {
        Button(action: {
            submit()
            presentationMode.wrappedValue.dismiss()
        }, label: {
            Text("Save")
                .foregroundColor(.white)
                .padding(.leading, 100)
                .padding(.trailing, 100)
                .padding(.top, 10)
                .padding(.bottom, 10)
        })
        .background(Color.blue)
        .cornerRadius(15)
    }

    var discardButton: some View {
        Button(action: {
            showDiscardAlert = true
        }, label: {
            Image(systemName: "xmark")
                .foregroundColor(.black)
                .padding()
                .clipShape(Circle())
        })
        .alert(isPresented: $showDiscardAlert) {
            Alert(
                title: Text("Discard Results"),
                message: Text("Are you sure you want to discard the results?"),
                primaryButton: .destructive(Text("Discard")) {
                    discard()
                },
                secondaryButton: .cancel()
            )
        }
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
                        .foregroundColor(Color.black)
                    LoopingPlayer(url: self.url, playbackRate: self.playbackRate, isUploadedVideo: false)
                        .offset(x: 0, y: -5)
                        .scaleEffect(x: 0.90, y: 0.90)
                    VStack {
                    Text("Score: \(score * 100)%")
                        .padding(.bottom, 10)
                        .foregroundColor(Color.black)
                    Text("Mistakes: MISTAKES")
                        .padding(.bottom, 10)
                        .foregroundColor(Color.black)
                    Text("Duration: \(Int(round(duration))) seconds")
                        .foregroundColor(Color.black)
                        .padding(.bottom, 20)
                    saveButton
                    }
                    .padding(.bottom, 30)
                }
                .background(Color.white)
            }
        }
    }

}
