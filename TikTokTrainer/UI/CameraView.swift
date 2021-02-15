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

    var CameraControls: some View {
        VStack {
            Button(action: {camera.switchCameraInput()}, label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .foregroundColor(.white)
                    .padding()
                    .clipShape(Circle())
            })
            .scaleEffect(CGSize(width: 1.5, height: 1.5))
            .padding(.trailing, 10)
            if camera.currentOrientation == .back {
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
    
    var RecordButton: some View {
        HStack {
            Button(action: {
                    camera.isRecording ?
                        camera.stopRecording() : camera.startRecording()
            }, label: {
                ZStack {
                    if camera.isRecording {
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
    
    var body: some View {
        ZStack {
            CameraPreview(currentImage: $camera.currentUIImage,
                          result: $camera.currentResult,
                          orientation: $camera.currentOrientation)
                .ignoresSafeArea(.all, edges: .all)
                .onTapGesture(count: 2) {
                    camera.switchCameraInput()
                }.zIndex(-1)
            VStack {
                if camera.hasPermission {
                    HStack {
                        Spacer()
                        if !camera.inErrorState {
                            CameraControls
                        }
                    }
                    Spacer()
                    RecordButton
                        .frame(height: 75)
                } else {
                    HStack {
                        Button(action: {permissions.openPermissionsSettings()}, label: {
                            ZStack {
                                Text("Enable camera access to continue")
                            }
                        })
                    }
                }
            }
        }
        .onAppear(perform: {
            camera.checkPermissionsAndSetup()
        })
    }
}

struct CameraView_Previews: PreviewProvider {
    static var cameraBack = CameraModel()
    
    static var previews: some View {
        Group {
            CameraView()
            CameraView()
                .RecordButton
                .background(Color.black)
                .previewLayout(.sizeThatFits)
            CameraView()
                .CameraControls
                .background(Color.black)
                .previewLayout(.sizeThatFits)
            CameraView(camera: cameraBack)
                .CameraControls
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .onAppear {
                    cameraBack.currentOrientation = .back
                }
        }
    }
}
