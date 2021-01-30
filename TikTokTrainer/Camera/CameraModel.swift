//
//  CameraFeed.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 1/29/21.
//

import Foundation
import AVFoundation
import SwiftUI
import Photos

class CameraModel: NSObject, ObservableObject,
                   AVCaptureFileOutputRecordingDelegate, AVCaptureMetadataOutputObjectsDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var hasPermission = true
    @Published var backCameraOn = true
    @Published var flashlightOn = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var backCamera: AVCaptureDevice!
    @Published var frontCamera: AVCaptureDevice!
    @Published var backInput: AVCaptureInput!
    @Published var frontInput: AVCaptureInput!
    @Published var outputURL: URL!
    @Published var isRecording = false
    @Published var view = UIView(frame: UIScreen.main.bounds)

    func check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            return
        default:
            return
        }
    }

    func setUp() {
        self.hasPermission.toggle()
        // start configuration
        self.session.beginConfiguration()

        // session specific configuration
        if self.session.canSetSessionPreset(.photo) {
            self.session.sessionPreset = .photo
        }
        self.session.automaticallyConfiguresCaptureDeviceForWideColor = true
        self.session.sessionPreset = AVCaptureSession.Preset.high

        // setup inputs
        // get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            self.backCamera = device
        } else {
            // Change this for CICD
            fatalError("no back camera")
        }

        // get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            self.frontCamera = device
        } else {
            // Change this for CICD
            fatalError("no front camera")
        }

        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            // Change this for CICD
            fatalError("could not create input device from back camera")
        }
        backInput = bInput
        if !session.canAddInput(backInput) {
            // Change this for CICD
            fatalError("could not add back camera input to capture session")
        }

        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            // Change this for CICD
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        if !session.canAddInput(frontInput) {
            // Change this for CICD
            fatalError("could not add front camera input to capture session")
        }

        self.session.addInput(backInput)

        // setup output
        self.session.addOutput(self.output)

        // commit configuration
        self.session.commitConfiguration()

        // start session
        self.session.startRunning()

    }

    func startRecord() {
        self.isTaken.toggle()
        if self.output.isRecording == false {
            let device = self.backCameraOn ? self.backCamera : self.frontCamera
            if (device?.isSmoothAutoFocusSupported)! {
                do {
                    try device?.lockForConfiguration()
                    device?.isSmoothAutoFocusEnabled = false
                    device?.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
            }
            self.outputURL = tempURL()
            self.output.startRecording(to: self.outputURL, recordingDelegate: self)
        } else {
            stopRecord()
        }
    }

    func stopRecord() {
        if self.output.isRecording == true {
            self.output.stopRecording()
        }
        self.isTaken.toggle()

        if self.flashlightOn {
            self.toggleFlash()
        }

        let when = DispatchTime.now() + 0.1
        DispatchQueue.main.asyncAfter(deadline: when) {
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.outputURL.path) {
                UISaveVideoAtPathToSavedPhotosAlbum(
                    self.outputURL.path,
                    nil,
                    nil,
                    nil
                )
            }
        }

    }

    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString

        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mov")
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!,
                 error: Error!) {
        print("captured")
        if error != nil {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.outputURL)
            }) { saved, error in
                if saved {
                    // todo
                } else {
                    print(error as Any)
                }
            }

        }
        outputURL = nil
    }

    func capture(_ captureOutput: AVCaptureFileOutput!,
                 didStartRecordingToOutputFileAt fileURL: URL!,
                 fromConnections connections: [Any]!) {

    }

    func switchCameraInput() {
           // don't let user spam the button, fun for the user, not fun for performance

           // reconfigure the input
           session.beginConfiguration()
           if backCameraOn {
                self.session.removeInput(self.backInput)
                self.session.addInput(self.frontInput)
                self.backCameraOn = false
                self.flashlightOn = false
           } else {
                self.session.removeInput(self.frontInput)
                self.session.addInput(self.backInput)
                self.backCameraOn = true
           }

           // deal with the connection again for portrait mode
            self.output.connections.first?.videoOrientation = .portrait

           // commit config
            self.session.commitConfiguration()
       }

    func setupPreviewLayer() {
        self.preview = AVCaptureVideoPreviewLayer(session: self.session)
        self.preview.frame = view.frame
        self.preview.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.preview)
    }

    func toggleFlash() {
        self.flashlightOn.toggle()
        if self.backCameraOn {
            guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
            guard device.hasTorch else { return }

            do {
                try device.lockForConfiguration()

                if device.torchMode == AVCaptureDevice.TorchMode.on {
                    device.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    do {
                        try device.setTorchModeOn(level: 1.0)
                    } catch {
                        print(error)
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        } else {
            print("Back camera needs to be selected for flash")
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {

    }
}
