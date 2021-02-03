//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 1/13/21.
//

import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject var camera = CameraModel()
    @StateObject var permissions = PermissionModel()
    
    var body: some View {
        ZStack {
            // Going to be camera preview
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            VStack {
                if !camera.hasPermission {
                    HStack {
                        Spacer()
                        if !camera.isCameraOn {
                            VStack {
                                Button(action: {camera.switchCameraInput()}, label: {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .foregroundColor(.white)
                                        .padding()
                                        .clipShape(Circle())
                                })
                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                .padding(.trailing, 10)
                                if camera.backCameraOn {
                                    Button(action: {camera.toggleFlash()}, label: {
                                        Image(systemName: camera.flashlightOn ? "bolt.fill" : "bolt")
                                            .foregroundColor(.white)
                                            .padding()
                                            .clipShape(Circle())
                                    })
                                    .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                    .padding(.trailing, 10)
                                }
                            }
                        }
                    }
                    Spacer()
                    RecordButton(camera: camera)
                        .frame(height: 75)
                } else {
                    HStack {
                        Button(action: {permissions.permissionDenied()}, label: {
                            ZStack {
                                Text("Enable camera access to continue")
                            }
                        })
                    }
                }
            }
        }
        .onAppear(perform: {
            camera.check()
        })
    }
}

struct RecordButton: View {
    @ObservedObject var camera: CameraModel
    
    var body: some View {
        HStack {
            Button(action: {
                    camera.isCameraOn ?
                        camera.stopRecord() : camera.toggleRecord()
            }, label: {
                ZStack {
                    if camera.isCameraOn {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 65, height: 65)
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: 75, height: 75)
                    } else {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 75, height: 75)
                    }
                }
            })
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
