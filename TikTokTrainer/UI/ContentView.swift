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
        ZStack {
            TabView(selection: $selectedTab) {
                Text("Tutorial")
                    .tabItem {
                        tabItem(iconName: "questionmark", text: "Tutorial", color: .white)
                    }
                    .tag(0)
                    .highPriorityGesture(DragGesture().onEnded(viewDragged))
                CameraView()
                    .tabItem {
                        tabItem(iconName: "video", text: "Record", color: .white)
                    }
                    .tag(1)
                    .highPriorityGesture(DragGesture().onEnded(viewDragged))
                Text("History")
                    .tabItem {
                        tabItem(iconName: "clock", text: "History", color: .white)
                    }
                    .tag(2)
                    .highPriorityGesture(DragGesture().onEnded(viewDragged))
            }
        }
        .accentColor(Color.red)
        .background(Color.black)
        .onAppear(perform: resetTabBarColor)
        .id(selectedTab)
    }

    private func viewDragged(_ val: DragGesture.Value) {
        guard abs(val.translation.width) > minDragThreshold else { print("Width: \(val.translation.width)"); return }
        
        if val.translation.width < 0 && self.selectedTab != 0 {
            self.selectedTab -= 1
        } else if val.translation.width > 0 && self.selectedTab < (numTabs-1) {
            self.selectedTab += 1
        } else {
            print("Width: \(val.translation.width)")
            print("Selected tab: \(self.selectedTab)")
        }
    }
}
