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
    @StateObject var permissions = PermissionHandler()
    @State var isCountingDown = false
    @State var timeRemaining = NumConstants.timerVal
    @State var timer: Timer?
    @State var recordTimer: Timer?
    @State var opacity = 0.0
    @State var pulse: Bool = false
    @State var isVideoUploaded: Bool = false
    @State var isVideoPickerOpen = false
    @State var isUploading: Bool = false
    @State var uploadedVideoDuration: Double = Double.infinity
    @State var progressView = UIProgressView()
    @State var uploadedVideoURL: URL = URL(string: "placeholder")!
    @State var thumbnailImage: UIImage = UIImage()
    @State var showDiscardAlert = false
    @State var playbackRate: Double = 1.0
    @State var playbackRateOptions = ["0.3", "0.5", "1.0", "2.0", "3.0"]
    @State var selectedPlayback = "1.0"
    @State var isPlayRateSelectorShowing = false

    var animatableData: Double {
        get { opacity }
        set { self.opacity = newValue }
    }

    func discard() {
        camera.isVideoRecorded = false
        self.opacity = 0.0
        self.showDiscardAlert = false
    }

    func reset() {
        self.opacity = 0.0
    }

    func submit() {
        print("submit button pressed")
    }

    func initializeTimerVars() {
        isCountingDown = false
        timer?.invalidate()
        timer = nil
        timeRemaining = NumConstants.timerVal
    }

    func setPlaybackRate(rate: String) {
        self.selectedPlayback = rate
        self.playbackRate = Double(rate)!
    }

    func startCountdown() {
        self.opacity = 0
        if camera.isRecording {
            camera.stopRecording(isEarly: true)
            self.reset()
        } else if isCountingDown {
            initializeTimerVars()
        } else {
            isCountingDown = true
            recordTimer = Timer.scheduledTimer(withTimeInterval: Double(NumConstants.timerVal) + (self.uploadedVideoDuration / self.playbackRate), repeats: false) { _ in
                if camera.isRecording {
                    camera.stopRecording(isEarly: false)
                }
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 1 {
                    timeRemaining -= 1
                } else {
                    initializeTimerVars()
                    camera.startRecording()
                }
            }
        }
    }

    var playRateSelected: some View {
        Rectangle()
            .fill()
            .foregroundColor(.white)
            .frame(width: 50, height: 25)
            .zIndex(0.0)
    }

    var playRate: some View {
        HStack {
            ForEach(playbackRateOptions, id: \.self) { item in
                ZStack {
                    if self.selectedPlayback == item {
                        playRateSelected
                        Button(action: {setPlaybackRate(rate: item)}, label: {Text(item + "x")})
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .zIndex(1.0)
                    } else {
                        Button(action: {setPlaybackRate(rate: item)}, label: {Text(item + "x")})
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .zIndex(1.0)
                    }
                }
            }
        }
    }

    var submitButton: some View {
        Button(action: {
            submit()
        }, label: {
            Text("Submit")
                .foregroundColor(.white)
                .clipShape(Rectangle())
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
        })
        .background(Color.blue)
        .padding(.trailing, 5)
    }

    var discardButton: some View {
        Button(action: {
            showDiscardAlert = true
        }, label: {
            Image(systemName: "xmark")
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .alert(isPresented: $showDiscardAlert) {
            Alert(
                title: Text("Discard Recording"),
                message: Text("Are you sure you want to discard the recording?"),
                primaryButton: .destructive(Text("Discard")) {
                    discard()
                },
                secondaryButton: .cancel()
            )
        }
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    var flipCameraControl: some View {
        Button(action: camera.switchCameraInput, label: {
            Image(systemName: IconConstants.cameraOutline)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    var flashControl: some View {
        Button(action: camera.toggleFlash, label: {
            Image(systemName: camera.flashlightOn ? IconConstants.flashOn : IconConstants.flash)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    var reuploadVideoControl: some View {
        Button(action: { self.isVideoUploaded = false }, label: {
            Image(systemName: IconConstants.uploadFile)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    var playRateControl: some View {
        Button(action: { self.isPlayRateSelectorShowing.toggle() }, label: {
            Image(systemName: IconConstants.speedometer)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
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
                    playRateControl
                }
            }
        }.padding()
    }

    var countdown: some View {
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
    }

    var recordButton: some View {
        HStack {
            Button(action: {
                startCountdown()
            }, label: {
                countdown
            })
        }
    }

    var playbackView: some View {
        HStack(spacing: 0) {
            LoopingPlayer(url: self.uploadedVideoURL, playbackRate: self.playbackRate, isUploadedVideo: true)
            LoopingPlayer(url: camera.outputURL, playbackRate: self.playbackRate, isUploadedVideo: false)
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
        ImagePicker(uploadedVideoURL: self.$uploadedVideoURL, isVideoPickerOpen: self.$isVideoPickerOpen, isVideoUploaded: self.$isVideoUploaded, thumbnailImage: self.$thumbnailImage, uploadedVideoDuration: self.$uploadedVideoDuration)
    }

    var uploadControlBackground: some View {
        Rectangle()
            .fill()
            .foregroundColor(.black)
            .ignoresSafeArea(.all, edges: .all)
            .scaleEffect(x: 1.0, y: NumConstants.yScale, anchor: .center)
            .zIndex(-1)
    }

    var background: some View {
        Rectangle()
            .fill()
            .ignoresSafeArea(.all)
            .background(Color.black)
            .foregroundColor(Color.black)
    }

    var uploadVideoButton: some View {
        VStack {
            Button(action: {self.isVideoPickerOpen = true}, label: {
                Image(systemName: IconConstants.uploadFileFilled)
                    .foregroundColor(.white)
                    .padding()
                    .clipShape(Circle())
            })
            .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
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

    var progressBar: some View {
        ZStack {
            ProgressBar(duration: Double(CMTimeGetSeconds(AVAsset(url: self.uploadedVideoURL).duration)) / self.playbackRate)
        }.zIndex(1)
    }

    var uploadedVideoPlayback: some View {
        VideoPlayerView(url: self.uploadedVideoURL, playbackRate: self.playbackRate)
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
                HStack(spacing: 0) {
                    ZStack {
                        uploadControlBackground
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
                    .offset(x: 0, y: -50)
            }
        }
    }

    var body: some View {
        ZStack {
            // Fill the background of the entire view with black
            background
            VStack(alignment: .leading) {
                if camera.isRecording {
                    progressBar
                }
                if camera.isVideoRecorded {
                    discardButton
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
                        VStack {
                            if self.isPlayRateSelectorShowing && !camera.isRecording && !self.isCountingDown {
                                playRate
                                    .padding(.bottom, 100)
                            }
                            recordButton
                                .frame(height: 75)
                        }
                    } else if !self.isVideoPickerOpen && self.isVideoUploaded && camera.isVideoRecorded {
                        submitButton
                            .frame(height: 75)
                            .offset(x: 0, y: -50)
                    }
                } else {
                    HStack {
                        Button(action: permissions.openPermissionsSettings, label: {
                            ZStack {
                                Text(StringConstants.permissionsCamera)
                            }
                        })
                    }
                }
            }
        }
        .sheet(isPresented: $isVideoPickerOpen) {
            imagePicker
        }
        .onAppear(perform: { camera.checkPermissionsAndSetup(permissions) })
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
