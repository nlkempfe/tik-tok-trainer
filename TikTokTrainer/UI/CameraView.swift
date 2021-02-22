//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 1/13/21.
//

import SwiftUI
import AVFoundation
import Photos
import AVKit

struct CameraView: View {
    @StateObject var camera = CameraModel()
    @StateObject var permissions = PermissionModel()
    @State var isCountingDown = false
    @State var timeRemaining = 3
    @State var timer: Timer?
    @State var recordTimer: Timer?
    @State var opacity = 0.0
    @State var pulse: Bool = false
    @State var isVideoUploaded: Bool = false
    @State var isVideoPickerOpen = false
    @State var isUploading: Bool = false
    @State var duration: Double = Double.infinity
    @State var progressView = UIProgressView()
    @State var uploadedVideoURL: URL = URL(string: "placeholder")!
    @State var thumbnailImage: UIImage = UIImage()

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

    func reset() {
        self.isVideoUploaded = false
        self.duration = Double.infinity
        self.opacity = 0.0
    }

    var flipCameraControl: some View {
        Button(action: camera.switchCameraInput, label: {
            Image(systemName: IconConstants.cameraOutline)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: 1.5, height: 1.5))
        .padding(.trailing, 5)
    }

    var flashControl: some View {
        Button(action: camera.toggleFlash, label: {
            Image(systemName: camera.flashlightOn ? IconConstants.flashOn : IconConstants.flash)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: 1.5, height: 1.5))
        .padding(.trailing, 5)
    }

    var reuploadVideoControl: some View {
        Button(action: self.reuploadFile, label: {
            Image(systemName: IconConstants.uploadFile)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: 1.5, height: 1.5))
        .padding(.trailing, 5)
    }

    var cameraControls: some View {
        VStack(spacing: 0) {
            if !self.isCountingDown && !camera.isRecording && !self.isVideoPickerOpen && !camera.isVideoRecorded {
                    flipCameraControl
                if camera.currentOrientation == .back {
                    flashControl
                }
                if self.isVideoUploaded {
                    reuploadVideoControl
                }
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
                    camera.stopRecording(isEarly: true)
                    self.reset()
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
                            timer?.invalidate()
                            timer = nil
                            timeRemaining = 3
                            camera.startRecording()
                            isCountingDown = false
                        }
                    }
                    recordTimer = Timer.scheduledTimer(withTimeInterval: self.duration + Double(timeRemaining), repeats: false) { _ in
                        if camera.isRecording {
                            camera.stopRecording(isEarly: false)
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

    var playbackView: some View {
        HStack(spacing: 0) {
            LoopingPlayer(url: self.uploadedVideoURL)
            LoopingPlayer(url: camera.outputURL)
        }.zIndex(1.0)
    }

    var dimmer: some View {
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

    var imagePicker: some View {
        ImagePicker(uploadedVideoURL: self.$uploadedVideoURL, isVideoPickerOpen: self.$isVideoPickerOpen, isVideoUploaded: self.$isVideoUploaded, thumbnailImage: self.$thumbnailImage, duration: self.$duration)
    }

    var background: some View {
        Rectangle()
            .fill()
            .foregroundColor(.black)
            .ignoresSafeArea(.all, edges: .all)
            .scaleEffect(x: 1.0, y: NumConstants.yScale, anchor: .center)
            .zIndex(-1)
    }

    var uploadVideoButton: some View {
        VStack {
            Button(action: {self.isVideoPickerOpen = true}, label: {
                Image(systemName: IconConstants.uploadFileFilled)
                    .foregroundColor(.white)
                    .padding()
                    .clipShape(Circle())
            })
            .scaleEffect(CGSize(width: 1.5, height: 1.5))
            Text(StringConstants.uploadVideo)
                .foregroundColor(.white)
                .font(.caption)
        }
    }

    var thumbnail: some View {
        Thumbnail(thumbnailImage: self.$thumbnailImage)
            .scaleEffect(x: 1.0, y: NumConstants.yScale, anchor: .center)
            .zIndex(-1.0)
            .background(Color.black)
    }

    var uploadedVideoPlayback: some View {
        Player(url: self.uploadedVideoURL)
            .scaleEffect(x: 1.0, y: 0.98, anchor: .center)
    }

    var liveCameraView: some View {
        CameraPreview(currentImage: $camera.currentUIImage,
                      result: $camera.currentResult,
                      orientation: $camera.currentOrientation)
            .ignoresSafeArea(.all, edges: .all)
            .scaleEffect(x: 1.0, y: NumConstants.yScale, anchor: .center)
            .onTapGesture(count: 2) {
                camera.switchCameraInput()
            }.zIndex(1.0)
            .background(Color.black)
    }

    var cameraPreview: some View {
        ZStack {
            if camera.currentUIImage != nil && !camera.isVideoRecorded {
                if isCountingDown {
                    dimmer
                }
                if self.isVideoPickerOpen {
                    imagePicker
                }
                HStack(spacing: 0) {
                    ZStack {
                        background
                        if !self.isVideoUploaded {
                            uploadVideoButton
                        } else if !camera.isRecording && self.isVideoUploaded {
                            thumbnail
                        } else if camera.isRecording {
                            uploadedVideoPlayback
                        }
                    }
                    liveCameraView
                }
                .zIndex(-1)
            } else if camera.currentUIImage != nil && camera.outputURL != nil {
                playbackView
            }
        }
    }

    var body: some View {
        ZStack {
            // Fill the background of the entire view with black
            Rectangle()
                .fill()
                .ignoresSafeArea(.all)
                .background(Color.black)
                .foregroundColor(Color.black)
            VStack(alignment: .leading) {
            if camera.isRecording {
                ZStack {
                    ProgressBar(duration: CMTimeGetSeconds(AVAsset(url: self.uploadedVideoURL).duration))
                }.zIndex(1)
            }
            cameraPreview
                .background(Color.black)
            }
            VStack {
                if camera.hasPermission {
                    HStack {
                        Spacer()
                        if !camera.inErrorState {
                            cameraControls
                        }
                    }
                    Spacer()
                    if !self.isVideoPickerOpen && self.isVideoUploaded && !camera.isVideoRecorded {
                    recordButton
                        .frame(height: 75)
                    }
                } else {
                    HStack {
                        Button(action: {permissions.openPermissionsSettings()}, label: {
                            ZStack {
                                Text(StringConstants.permissionsCamera)
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
//            CameraView()
//            CameraView()
//                .recordButton
//                .background(Color.black)
//                .previewLayout(.sizeThatFits)
//            CameraView()
//                .cameraControls
//                .background(Color.black)
//                .previewLayout(.sizeThatFits)
//            CameraView(camera: cameraBack)
//                .cameraControls
//                .background(Color.black)
//                .previewLayout(.sizeThatFits)
//                .onAppear {
//                    cameraBack.currentOrientation = .back
//                }
//            CameraView()
//                .cameraPreview
//                .background(Color.black)
//            CameraView()
//                .cameraPreview
//                .scaleEffect(0.5)
        }
    }
}
