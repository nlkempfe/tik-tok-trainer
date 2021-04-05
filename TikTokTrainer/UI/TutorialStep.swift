//
//  TutorialStep.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 4/5/21.
//

import Foundation
import SwiftUI

struct TutorialStep: View {

    var step: String
    var header: String
    var details: String

    var body: some View {
        HStack {
            Text(step)
            .bold()
            .padding(8)
            .foregroundColor(Color.white)
            .background(Color.blue)
            .clipShape(Circle())
        Text(header)
            .bold()
            .foregroundColor(Color.black)
        }
        if details.count > 0 {
            Text(details)
                .foregroundColor(Color.gray)
                .padding(.leading, 32)
                .padding(.top, -12)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
