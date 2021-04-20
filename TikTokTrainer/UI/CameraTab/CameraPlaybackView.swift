//
//  CameraPlaybackView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 4/4/21.
//

import SwiftUI
import Promises
import AVFoundation

struct CameraPlaybackView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @ObservedObject var camera: CameraModel
    @ObservedObject var permissions: PermissionHandler
    @Binding var selectedVideo: SelectedVideo?
    @State var showDiscardAlert: Bool = false
    @State var showResultsScreen: Bool = false
    @State var dimmerOpacity = 0.8
    @State var showLoadingScreen: Bool = false
    @State var score: Double = Double.nan
    @State var mistakes: [CGFloat] = []
    @State var resultOutcome: ResultsOutcome?

    var animatableData: Double {
        get { dimmerOpacity }
        set { self.dimmerOpacity = newValue }
    }

    func showDiscardButtonAction() {
        self.showDiscardAlert = true
        camera.cameraSession.stopRunning()
    }

    func discard() {
        camera.isVideoRecorded = false
        self.showDiscardAlert = false
        camera.reset()
        camera.checkPermissionsAndSetup(permissions)
    }

    func submit() {
        self.showLoadingScreen = true
        // Run PoseNetProcessor on two videos and feed result to scoring function
        all(
            PoseNetProcessor.run(url: self.selectedVideo!.videoURL),
            PoseNetProcessor.run(url: self.camera.previousSavedURL)
        ).then { movieOne, movieTwo in
            return ScoringFunction(preRecordedVid: movieOne, recordedVid: movieTwo).computeScore()
        }.then { score, mistakes in
            self.showLoadingScreen = false
            self.score = score.isNaN ? 0 : Double(score)
            self.score = (self.score * 10000).rounded() / 100
            self.mistakes = mistakes
            self.showResultsScreen = true
        }.catch { error in
            print("Error scoring videos: \(error)")
        }
    }

    var loadingScreen: some View {
        ZStack {
            Rectangle()
                .fill()
                .foregroundColor(.black)
                .opacity(0.85)
                .ignoresSafeArea(.all, edges: .all)
                .onAppear {
                    withAnimation {
                        self.dimmerOpacity = 0.5
                    }
                }
            VStack {
                Text(StringConstants.loadingTitle)
                    .foregroundColor(.white)
                    .font(.title)
                    .padding(.top, 50)
                Text(StringConstants.loadingSubtitle)
                    .foregroundColor(.gray)
                    .font(.caption)
                Spacer()
            }
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                .foregroundColor(.white)
                .zIndex(2.0)
                .scaleEffect(x: 1.5, y: 1.5)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                HStack {
                    if !self.showLoadingScreen {
                        Button(action: {
                            showDiscardButtonAction()
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
                        Spacer()
                    }
                }
                HStack(spacing: 0) {
                    if self.selectedVideo != nil {
                        LoopingPlayer(url: self.selectedVideo!.videoURL, playbackRate: self.selectedVideo?.playbackRate ?? 1.0, isUploadedVideo: true, isMuted: true)
                        LoopingPlayer(url: camera.outputURL, playbackRate: self.selectedVideo?.playbackRate ?? 1.0, isUploadedVideo: false, isMuted: true)
                    }
                }.zIndex(1.0)
                .offset(y: 25)
                Button(action: {
                    if !self.showLoadingScreen {
                        submit()
                    }
                }, label: {
                    Text("Submit Video")
                        .foregroundColor(.white)
                        .clipShape(Rectangle())
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                })
                .fullScreenCover(isPresented: $showResultsScreen) {
                    ResultsView(resultOutcome: $resultOutcome,
                                score: self.score,
                                mistakes: self.mistakes,
                                duration: self.selectedVideo!.videoDuration,
                                recording: self.camera.previousSavedURL,
                                tutorial: self.selectedVideo!.videoURL,
                                playbackRate: self.selectedVideo!.playbackRate)
                        .ignoresSafeArea(.all, edges: .all)
                }
                .background(Color.blue)
                .padding(.trailing, 5)
                .padding(.bottom, 30)
                .ignoresSafeArea(.all)
                .onChange(of: resultOutcome, perform: { _ in
                    self.selectedVideo = nil
                    self.camera.reset()
                })
            }
            if showLoadingScreen {
                loadingScreen
            }
        }
    }
}

struct CameraPlaybackView_Previews: PreviewProvider {
    static var previews: some View {
        CameraPlaybackView(camera: CameraModel(), permissions: PermissionHandler(), selectedVideo: .constant(nil))
    }
}
