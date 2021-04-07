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
    let rgbValue = 0x141414
    let minDragThreshold: CGFloat = 50.0
    let numTabs = 3

    init() {
        resetTabBarColor()
    }

    func resetTabBarColor() {
        UITabBar.appearance().isTranslucent = false
    }

    func tabItem(iconName: String, text: String, color: Color) -> some View {
        VStack {
            Label(text, systemImage: iconName)
                .foregroundColor(color)
        }
    }

    var body: some View {
        StatefulTabView(selectedIndex: $selectedTab) {
            Tab(title: "Tutorial", systemImageName: "clock") {
                    TutorialView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
            Tab(title: "Record", systemImageName: "video") {
                    CameraTabView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
            Tab(title: "History", systemImageName: "questionmark") {
                    HistoryView()
                        .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
        }
        .barTintColor(.red)
        .unselectedItemTintColor(.gray)
        .barAppearanceConfiguration(.transparent)
        .barBackgroundColor(UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        ))
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
