//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 2/21/21.
//

import Foundation
import SwiftUI

enum MainTabs {
    case tutorialTab,
         cameraTab,
         historyTab
}

struct ContentView: View {

    @State private var selectedTab: MainTabs = .cameraTab

    init() {
        resetTabBarColor()
    }

    func resetTabBarColor() {
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = (selectedTab == .cameraTab ? UIColor.black : UIColor.white)
        UITabBar.appearance().backgroundColor = (selectedTab == .cameraTab ? UIColor.black : UIColor.white)
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
                    .tag(MainTabs.tutorialTab)
                CameraView()
                    .tabItem {
                        tabItem(iconName: "video", text: "Record", color: .white)
                    }
                    .tag(MainTabs.cameraTab)
                HistoryView()
                    .tabItem {
                        tabItem(iconName: "clock", text: "History", color: .white)
                    }
                    .tag(MainTabs.historyTab)
            }
        }
        .accentColor(Color.red)
        .background(Color.black)
        .onAppear(perform: resetTabBarColor)
        .id(selectedTab)
    }
}
