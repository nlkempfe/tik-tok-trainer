//
//  TutorialView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 3/23/21.
//

import Foundation
import SwiftUI

struct TutorialView: View {

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    Text("WE'RE HERE TO HELP")
                        .foregroundColor(Color.gray)
                        .padding(.bottom, -12)
                        .font(Font.caption)
                    Text("How this app works")
                        .bold()
                        .font(Font.title)
                        .padding(.bottom, 10)
                        .padding(.top, 10)
                        .foregroundColor(Color.black)
                      VStack(alignment: .leading, spacing: 10) {
                          TutorialStep(step: "1", header: "Upload a video.", details: "Upload a video of a dance you'd like to learn using the \'Upload a Video\' button. Using the icons in the upper-right corner, you can flip the camera, choose a different video to upload, or change the playback speed of the uploaded video.")
                          TutorialStep(step: "2", header: "Hit the record button and a countdown will begin.", details: "")
                          TutorialStep(step: "3", header: "Get positioned.", details: "Setup your device approximately 3-6 feet away, and get ready to dance.")
                          TutorialStep(step: "4", header: "Dance.", details: "The video will automatically stop recording when the length is the same as the uploaded video.")
                          TutorialStep(step: "5", header: "Review your video.", details: "If you like the way your video looks, hit the \'Submit Video\' button. Your video will then be analyzed against the tutorial video.")
                          TutorialStep(step: "6", header: "Review results.", details: "After the analysis is complete, you can view your score, how many mistakes you made, and the duration of your video. If you'd like to save these results, press the \'Save\' button.")
                          TutorialStep(step: "7", header: "View history.", details: "To view your saved results, go to the history tab.")
                      }
                      .padding(.bottom, 10)
                      .padding(.leading, 20)
                      .padding(.trailing, 20)
                }
          }
            Rectangle()
                .ignoresSafeArea(.all)
                .background(Color.white)
                .zIndex(-1.0)
        }
    }
}
