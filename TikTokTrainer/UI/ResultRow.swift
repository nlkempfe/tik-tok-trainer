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
    
    var body: some View {
        VStack {
            Text("Resulted: ") + Text(result.timestamp ?? Date.init(), style: .date) + Text(" ") + Text(result.timestamp ?? Date.init(), style: .time)
                .foregroundColor(Color.black)
            Text("Score: \(result.score * 100)%")
                .foregroundColor(Color.black)
        }
    }
}
