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
    @State var isCountingDown = false
    @State var timeRemaining = 3
    @State var timer: Timer?
    @State var opacity = 0.0
    @State var pulse: Bool = false
    @State var isVideoUploaded = false

    var animatableData: Double {
        get { opacity }
        set { self.opacity = newValue }
    }

    // MARK: - Placeholders
    func uploadFile() {
        print("file upload tapped")
        self.isVideoUploaded = true
    }

    func reuploadFile() {
        print("reupload file tapped")
        self.isVideoUploaded = false
    }

    // MARK: - End placeholders

    var cameraControls: some View {
        VStack(spacing: 0) {
            Button(action: {camera.switchCameraInput()}, label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .foregroundColor(.white)
                    .padding()
                    .clipShape(Circle())
            })
            .scaleEffect(CGSize(width: 1.5, height: 1.5))
            .padding(.trailing, 5)
            if camera.currentOrientation == .back {
                Button(action: {camera.toggleFlash()}, label: {
                    Image(systemName: camera.flashlightOn ? "bolt.fill" : "bolt")
                        .foregroundColor(.white)
                        .padding()
                        .clipShape(Circle())
                })
                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                .padding(.trailing, 5)
            }
            if self.isVideoUploaded && !camera.isRecording {
                Button(action: {self.reuploadFile()}, label: {
                    Image(systemName: "plus.square")
                        .foregroundColor(.white)
                        .padding()
                        .clipShape(Circle())
                })
                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                .padding(.trailing, 5)
            }
        }.padding()
    }

    var recordButton: some View {
        /*
         todo: add logic to prevent user from recording without first uploading a comparison video
         leaving as-is for testing as of now
         */
        HStack {
            Button(action: {
                self.opacity = 0
                if camera.isRecording {
                    camera.stopRecording()
                } else if isCountingDown {
                    isCountingDown = false
                    timer?.invalidate()
                    timer = nil
                    timeRemaining = 3
                } else {
                    isCountingDown = true
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        if timeRemaining > 1 {
                            timeRemaining -= 1
                        } else {
                            isCountingDown = false
                            timer?.invalidate()
                            timer = nil
                            timeRemaining = 3
                            camera.startRecording()
                        }
                    }
                }
            }, label: {
                ZStack {
                    if isCountingDown {
                        Text("\(timeRemaining)")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: 75, height: 75)
                    } else if camera.isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 65, height: 65)
                            .scaleEffect(self.pulse ? 0.8 : 1.0)
                            .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: true))
                            .onAppear {
                                self.pulse.toggle()
                            }
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

    var cameraPreview: some View {
            ZStack {
                if camera.currentUIImage != nil {
                    if isCountingDown {
                    Rectangle()
                        .fill()
                        .foregroundColor(.black)
                        .opacity(opacity)
                        .ignoresSafeArea(.all, edges: .all)
                        .onAppear {
                            withAnimation {
                                self.opacity = 0.8
                            }
                        }
                    }
                    HStack(spacing: 0) {
                        ZStack {
                    Rectangle()
                        .fill()
                        .foregroundColor(.black)
                        .ignoresSafeArea(.all, edges: .all)
                        .scaleEffect(x: 1.0, y: 0.5, anchor: .center/*@END_MENU_TOKEN@*/)
                        .zIndex(-2)
                            VStack {
                            Button(action: {self.uploadFile()}, label: {
                                Image(systemName: "plus.square.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .clipShape(Circle())
                            })
                            .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                Text("Upload a video")
                                    .foregroundColor(.white)
                                    .font(.caption)
                        }
                        }
                    CameraPreview(currentImage: $camera.currentUIImage,
                            result: $camera.currentResult,
                            orientation: $camera.currentOrientation)
                    .ignoresSafeArea(.all, edges: .all)
                        .scaleEffect(x: 1.0, y: 0.5, anchor: .center/*@END_MENU_TOKEN@*/)
                    .onTapGesture(count: 2) {
                        camera.switchCameraInput()
                    }.zIndex(-1)
                        .background(Color.black)

                    }
                    .zIndex(-1)
                }
        }
    }

    var body: some View {
        ZStack {
            cameraPreview
            VStack {
                if camera.hasPermission {
                    HStack {
                        Spacer()
                        if !camera.inErrorState {
                            cameraControls
                        }
                    }
                    Spacer()
                    recordButton
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
                .recordButton
                .background(Color.black)
                .previewLayout(.sizeThatFits)
            CameraView()
                .cameraControls
                .background(Color.black)
                .previewLayout(.sizeThatFits)
            CameraView(camera: cameraBack)
                .cameraControls
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .onAppear {
                    cameraBack.currentOrientation = .back
                }
            CameraView()
                .cameraPreview
                .background(Color.black)
            CameraView()
                .cameraPreview
                .scaleEffect(0.5)
        }
    }
}
