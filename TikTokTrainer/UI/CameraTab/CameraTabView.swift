//
//  CameraTabView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 4/3/21.
//

import SwiftUI

struct CameraTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @StateObject var camera = CameraModel()
    @StateObject var permissions = PermissionHandler()
    @State var selectedVideo: SelectedVideo?
    @State var processedVideoResult: ProcessedVideoResult?
    
    var fillBackground: some View {
        Rectangle()
            .fill()
            .ignoresSafeArea(.all)
            .background(Color.black)
            .foregroundColor(Color.black)
    }

    var body: some View {
        ZStack {
            fillBackground
            if camera.hasPermission {
                if !camera.isVideoRecorded || selectedVideo == nil {
                    CameraRecordView(camera: camera, selectedVideo: $selectedVideo)
                } else {
                    CameraPlaybackView(camera: camera, permissions: permissions, selectedVideo: $selectedVideo)
                }
            } else {
                NoCameraPermissionsView()
            }
        }.onAppear(perform: {
            camera.checkPermissionsAndSetup(permissions)
        })
    }
}

struct CameraTabView_Previews: PreviewProvider {
    static var previews: some View {
        CameraTabView()
    }
}
