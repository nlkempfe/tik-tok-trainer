//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 2/21/21.
//

import Foundation
import SwiftUI

struct ContentView: View {

    @State private var selectedTab = 0
    let numTabs = 3

    init() {
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = UIColor.black
        UITabBar.appearance().backgroundColor = UIColor.black
    }

    var body: some View {
//        ZStack {
//            Rectangle()
//                .fill()
//                .ignoresSafeArea(.all)
//                .background(Color.black)
//                .foregroundColor(Color.black)
//            TabView(selection: $selectedTab) {
//                Text("First")
//                    .tabItem {
//                        Image(systemName: "questionmark")
//                            Text("Tutorial")
//                            .foregroundColor(.white)
//                    }
//                    .tag(0)
                CameraView()
//                    .tabItem {
//                        Image(systemName: "video")
//                        Text("Record")
//                            .foregroundColor(.white)
//                    }
//                    .tag(1)
//                Text("History")
//                    .tabItem {
//                        Image(systemName: "clock")
//                        Text("History")
//                            .foregroundColor(.white)
//                    }
//                    .tag(2)
//            }
//        }
//        .accentColor(Color.red)
//        .background(Color.black)
    }
}
