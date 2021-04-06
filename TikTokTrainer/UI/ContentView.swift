//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Natascha Kempfe on 2/21/21.
//

import Foundation
import SwiftUI
import StatefulTabView

enum MainTabs {
    case tutorialTab,
         cameraTab,
         historyTab
}

struct ContentView: View {

    @State private var selectedTab = 1
    let minDragThreshold: CGFloat = 50.0
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
        StatefulTabView(selectedIndex: $selectedTab) {
            Tab(title: "History", systemImageName: "questionmark") {
                    HistoryView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
            Tab(title: "Record", systemImageName: "video") {
                    CameraTabView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
            Tab(title: "Tutorial", systemImageName: "clock") {
                    TutorialView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
        }
        .barTintColor(.red)
        .unselectedItemTintColor(.gray)
        .barBackgroundColor(.clear)
        .barAppearanceConfiguration(.transparent)
    }

    private func viewDragged(_ val: DragGesture.Value) {
        guard abs(val.translation.width) > minDragThreshold else { print("Width: \(val.translation.width)"); return }

        if val.translation.width > 0 && self.selectedTab != 0 {
            self.selectedTab -= 1
        } else if val.translation.width < 0 && self.selectedTab < (numTabs-1) {
            self.selectedTab += 1
        } else {
            print("Width: \(val.translation.width)")
            print("Selected tab: \(self.selectedTab)")
        }
    }
}
