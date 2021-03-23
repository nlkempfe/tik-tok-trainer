//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 2/21/21.
//

import Foundation
import SwiftUI

struct ContentView: View {

    @State private var selectedTab = 1
    let numTabs = 3

    init() {
        resetTabBarColor()
    }

    func resetTabBarColor() {
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = (selectedTab == 1 ? UIColor.black : UIColor.white)
        UITabBar.appearance().backgroundColor = (selectedTab == 1 ? UIColor.black : UIColor.white)
    }

    func tabItem(iconName: String, text: String, color: Color) -> some View {
        VStack {
            Label(text, systemImage: iconName)
                .foregroundColor(color)
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TutorialView()
                    .tabItem {
                        tabItem(iconName: "questionmark", text: "Tutorial", color: .white)
                    }
                    .tag(0)
                CameraView()
                    .tabItem {
                        tabItem(iconName: "video", text: "Record", color: .white)
                    }
                    .tag(1)
                HistoryView()
                    .tabItem {
                        tabItem(iconName: "clock", text: "History", color: .white)
                    }
                    .tag(2)
            }
        }
        .accentColor(Color.red)
        .background(Color.black)
        .onAppear(perform: resetTabBarColor)
        .id(selectedTab)
    }
}
