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
            VStack {
                Text("T3 Tutorial")
                    .font(Font.title)
                    .padding(.bottom, 50)
                    .foregroundColor(Color.black)
                VStack(alignment: .leading, spacing: 10) {
                    Text("1.").bold().foregroundColor(Color.black) + Text(" Upload a video of a dance you'd like to learn using the \'Upload a Video\' button. Using the icons in the upper-right corner, you can flip the camera, choose a different video to upload, or change the playback speed of the uploaded video.").foregroundColor(Color.black)
                    Text("2.").bold().foregroundColor(Color.black) + Text(" Hit the record button and a countdown will begin.").foregroundColor(Color.black)
                    Text("3.").bold().foregroundColor(Color.black) + Text(" Setup your device approximately 3-6 feet away, and get ready to dance.").foregroundColor(Color.black)
                    Text("4.").bold().foregroundColor(Color.black) + Text(" The video will automatically stop recording when the length is the same as the uploaded video.").foregroundColor(Color.black)
                    Text("5.").bold().foregroundColor(Color.black) + Text(" If you don't like the way your video looks, you can discard your video using the \'X\' button in the upper-left corner. If you like the way your video looks, hit the \'Submit Video\' button. Your video will then be analyzed against the tutorial video.").foregroundColor(Color.black)
                    Text("6.").bold().foregroundColor(Color.black) + Text(" After the analysis is complete, you can view your score, how many mistakes you made, and the duration of your video.").foregroundColor(Color.black)
                    Text("7.").bold().foregroundColor(Color.black) + Text(" If you'd like to save these results, press the \'Save\' button. Otherwise, you can discard them using the \'X\' button in the upper-left corner.").foregroundColor(Color.black)
                    Text("8.").bold().foregroundColor(Color.black) + Text(" To view your saved results, go to the history tab.").foregroundColor(Color.black)
                }
                .padding(.bottom, 10)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }
            Rectangle()
                .ignoresSafeArea(.all)
                .background(Color.white)
                .zIndex(-1.0)
        }
    }
}
