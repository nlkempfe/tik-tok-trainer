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
        VStack {
            Text("T3 Tutorial")
                .font(Font.title)
                .padding(.bottom, 50)
            VStack(alignment: .leading, spacing: 10) {
                Text("1.").bold() + Text(" Upload a video of a dance you'd like to learn using the \'Upload a Video\' button. Using the icons in the upper-right corner, you can flip the camera, choose a different video to upload, or change the playback speed of the uploaded video.")
                Text("2.").bold() + Text(" Hit the record button and a countdown will begin.")
                Text("3.").bold() + Text(" Setup your device approximately 3-6 feet away, and get ready to dance.")
                Text("4.").bold() + Text(" The video will automatically stop recording when the length is the same as the uploaded video.")
                Text("5.").bold() + Text(" If you don't like the way your video looks, you can discard your video using the \'X\' button in the upper-left corner. If you like the way your video looks, hit the \'Submit Video\' button. Your video will then be analyzed against the tutorial video.")
                Text("6.").bold() + Text(" After the analysis is complete, you can view your score, how many mistakes you made, and the duration of your video.")
                Text("7.").bold() + Text(" If you'd like to save these results, press the \'Save\' button. Otherwise, you can discard them using the \'X\' button in the upper-left corner.")
                Text("8.").bold() + Text(" To view your saved results, go to the history tab.")
            }
            .padding(.bottom, 10)
            .padding(.leading, 20)
            .padding(.trailing, 20)
        }
    }
}
