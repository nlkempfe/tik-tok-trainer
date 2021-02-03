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
                .ignoresSafeArea()
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
                                    if !camera.flashlightOn {
                                        Button(action: {camera.toggleFlash()}, label: {
                                            Image(systemName: "bolt")
                                                .foregroundColor(.white)
                                                .padding()
                                                .clipShape(Circle())
                                            })
                                            .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                            .padding(.trailing, 10)
                                        } else {
                                            Button(action: {camera.toggleFlash()}, label: {
                                            Image(systemName: "bolt.fill")
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
                    }
                Spacer()
                HStack {
                    if camera.isCameraOn {
                        Button(action: {camera.stopRecord()}, label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 65, height: 65)
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    } else {
                        Button(action: {camera.toggleRecord()}, label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    }
                }
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

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
