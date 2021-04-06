//
//  CameraRecordView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 4/4/21.
//

import SwiftUI
import AVFoundation

struct CameraRecordView: View {

    @ObservedObject var camera: CameraModel

    @Binding var selectedVideo: SelectedVideo?
    @State var timeRemaining = NumConstants.timerVal
    @State var countdownTimer: Timer?
    @State var recordTimer: Timer?
    @State var isRecording: Bool = false
    @State var isCountingDown: Bool = false
    @State var showPlaybackRate: Bool = false
    @State var pulseRecordButton: Bool = false
    @State var dimmerOpacity = 0.8
    @State var selectedPlaybackRate: Double = 1.0
    @State var isVideoPickerOpen: Bool = false
    @State var playbackRateOptions: [Double] = [0.3, 0.5, 1.0, 2.0]

    var animatableData: Double {
        get { dimmerOpacity }
        set { self.dimmerOpacity = newValue }
    }

    func initializeTimerVars() {
        isCountingDown = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        timeRemaining = NumConstants.timerVal
    }

    func startCountdown() {
        self.dimmerOpacity = 0
        if camera.isRecording {
            camera.stopRecording(isEarly: true)
        } else if isCountingDown {
            initializeTimerVars()
        } else {
            isCountingDown = true
            recordTimer = Timer.scheduledTimer(withTimeInterval: Double(NumConstants.timerVal) + (self.selectedVideo!.videoDuration / self.selectedPlaybackRate), repeats: false) { _ in
                if camera.isRecording {
                    camera.stopRecording(isEarly: false)
                }
                self.selectedVideo?.playbackRate = self.selectedPlaybackRate
            }
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 1 {
                    timeRemaining -= 1
                } else {
                    initializeTimerVars()
                    camera.startRecording()
                }
            }
        }
    }

    func makeControl(action: @escaping () -> Void, icon: String) -> some View {
        return Button(action: action, label: {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding()
                .clipShape(Circle())
        })
        .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
        .padding(.trailing, 5)
    }

    func roundDecimal(_ num: Double) -> String {
        return String(format: "%.1f", num)
    }

    func playRateOption(rate: Double) -> some View {
        return ZStack {
            if self.selectedPlaybackRate == rate {
                Rectangle()
                    .fill()
                    .foregroundColor(.white)
                    .frame(width: 50, height: 25)
                    .zIndex(0.0)
            }
            Button(action: {self.selectedPlaybackRate = rate}, label: {Text("\(roundDecimal(rate))x")})
                .foregroundColor(self.selectedPlaybackRate == rate ? .black : .white)
                .frame(maxWidth: .infinity)
                .zIndex(1.0)
        }
    }

    var playRate: some View {
        HStack {
            ForEach(self.playbackRateOptions, id: \.self) { item in
                playRateOption(rate: item)
            }
        }
    }

    var cameraControls: some View {
        VStack(spacing: 0) {
            if !self.camera.isVideoRecorded {
                // Flip camera
                makeControl(action: camera.switchCameraInput, icon: IconConstants.cameraOutline)
                if camera.currentOrientation == .back {
                    // Toggle flash
                    makeControl(action: camera.toggleFlash, icon: camera.flashlightOn ? IconConstants.flashOn : IconConstants.flash)
                }
                if self.selectedVideo != nil && !self.camera.isRecording {
                    // Change selected video
                    makeControl(action: { self.selectedVideo = nil }, icon: IconConstants.uploadFile)
                    // Playback control
                    makeControl(action: { self.showPlaybackRate.toggle() }, icon: IconConstants.speedometer)
                }
            }
        }.padding()
    }

    var countdownButton: some View {
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
                    .scaleEffect(self.pulseRecordButton ? 0.8 : 1.0)
                    .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: true))
                    .onAppear {
                        self.pulseRecordButton.toggle()
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

    var dimmer: some View {
        Rectangle()
            .fill()
            .foregroundColor(.black)
            .opacity(dimmerOpacity)
            .ignoresSafeArea(.all, edges: .all)
            .onAppear {
                withAnimation {
                    self.dimmerOpacity = 0.8
                }
            }
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

    var uploadVideoButton: some View {
        VStack {
            Button(action: {
                    self.isVideoPickerOpen = true
            }, label: {
                Image(systemName: IconConstants.uploadFileFilled)
                    .foregroundColor(.white)
                    .padding()
                    .clipShape(Circle())
            })
            .sheet(isPresented: $isVideoPickerOpen) {
                ImagePicker(uploadedVideo: self.$selectedVideo, isVideoPickerOpen: self.$isVideoPickerOpen, isLandscape: .constant(false))
            }
            .scaleEffect(CGSize(width: NumConstants.iconXScale, height: NumConstants.iconYScale))
            Text(StringConstants.uploadVideo)
                .foregroundColor(.white)
                .font(.caption)
        }
    }

    var cameraPreview: some View {
        ZStack {
            if self.isCountingDown {
                self.dimmer
            }
            HStack(spacing: 0) {
                VStack {
                    if self.selectedVideo == nil {
                        uploadVideoButton
                    } else if !camera.isRecording {
                        Image(uiImage: self.selectedVideo!.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .zIndex(-1.0)
                            .background(Color.black)
                    } else if camera.isRecording {
                        VideoPlayerView(url: self.selectedVideo!.videoURL, playbackRate: self.selectedPlaybackRate)
                    }
                }.frame(minWidth: 0, maxWidth: .infinity)
                CameraPreview(currentImage: $camera.currentUIImage,
                              result: $camera.currentResult,
                              orientation: $camera.currentOrientation)
                    .ignoresSafeArea(.all, edges: .all)
                    .onTapGesture(count: 2) {
                        camera.switchCameraInput()
                    }.zIndex(1.0)
                    .background(Color.black)
            }
            .zIndex(-1)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if camera.isRecording {
                ZStack {
                    ProgressBar(duration: Double(CMTimeGetSeconds(AVAsset(url: self.selectedVideo!.videoURL).duration)) / self.selectedPlaybackRate)
                }.zIndex(1)
            }
            cameraPreview
        }
        VStack {
            HStack {
                Spacer()
                cameraControls
            }
            Spacer()

            if !self.camera.isVideoRecorded {
                VStack {
                    if self.showPlaybackRate {
                        playRate
                            .padding(.bottom, 75)
                    }
                    if self.selectedVideo != nil {
                        // Record Button
                        Button(action: {
                            startCountdown()
                        }, label: {
                            countdownButton
                        }).padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear(perform: {
            camera.setup()
        })
    }
}

// struct CameraRecordView_Previews: PreviewProvider {
//    static var previews: some View {
//       CameraRecordView(camera: CameraModel(), selectedVideoURL: .constant(nil))
//    }
// }
