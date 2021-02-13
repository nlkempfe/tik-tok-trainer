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
import Vision
import VideoToolbox
import MetalKit

class CameraModel: NSObject, ObservableObject,
                   AVCaptureFileOutputRecordingDelegate,
                   AVCaptureMetadataOutputObjectsDelegate,
                   AVCaptureVideoDataOutputSampleBufferDelegate {

    // toggles
    @Published var backCameraOn = false
    @Published var flashlightOn = false
    @Published var isCameraOn = false
    @Published var isRecording = false
    @Published var backCamera: AVCaptureDevice!
    @Published var frontCamera: AVCaptureDevice!
    @Published var backInput: AVCaptureInput!
    @Published var frontInput: AVCaptureInput!

    // camera feed
    @Published var cameraSession = AVCaptureSession()
    @Published var fileOutput = AVCaptureMovieFileOutput()
    @Published var dataOutput = AVCaptureVideoDataOutput()
    @Published var hasPermission = true
    @Published var outputURL: URL!
    @Published var imageBounds: CGSize!
    @Published var currentUIImage: UIImage? = nil
    @Published var currentResult: PoseNetResult? = nil

    // queue for processing video data to posenet
    private let posenetDataQueue = DispatchQueue(
        label: "T3.posenetDataQueue")

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
        self.cameraSession.beginConfiguration()

        // session specific configuration
        if self.cameraSession.canSetSessionPreset(.photo) {
            self.cameraSession.sessionPreset = .photo
        }
        self.cameraSession.automaticallyConfiguresCaptureDeviceForWideColor = true
        self.cameraSession.sessionPreset = AVCaptureSession.Preset.high

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
        if !cameraSession.canAddInput(backInput) {
            // Change this for CICD
            fatalError("could not add back camera input to capture session")
        }

        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            // Change this for CICD
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        if !cameraSession.canAddInput(frontInput) {
            // Change this for CICD
            fatalError("could not add front camera input to capture session")
        }

        self.cameraSession.addInput(frontInput)

        self.dataOutput.alwaysDiscardsLateVideoFrames = true
        self.dataOutput.setSampleBufferDelegate(self, queue: posenetDataQueue)

        // TODO: setup file capture output, this is gonna be interesting because we should sync it up with MTKView
        // self.cameraSession.addOutput(self.fileOutput)
        self.cameraSession.addOutput(self.dataOutput)

        self.dataOutput.connections.first?.videoOrientation = .portrait

        // commit configuration
        self.cameraSession.commitConfiguration()

        // start session
        self.cameraSession.startRunning()
    }

    // MARK: - Recording
    func toggleRecord() {
        self.isCameraOn.toggle()
        if self.fileOutput.isRecording == false {
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

            // generate a url for where this video will be saved
            self.outputURL = tempURL()
            self.fileOutput.startRecording(to: self.outputURL, recordingDelegate: self)
        } else {
            stopRecord()
        }
    }

    func stopRecord() {
        if self.fileOutput.isRecording == true {
            self.fileOutput.stopRecording()
        }
        self.isCameraOn.toggle()

        // turn off flashlight if it's on
        if self.flashlightOn {
            self.toggleFlash()
        }

        // for some reason, this fixes the bug where you can only record 1 video without rebuilding the app
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

    // save recording to gallery
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
        // protocol method
    }

    // MARK: - Camera Toggles
    func switchCameraInput() {
        // don't let user spam the button, fun for the user, not fun for performance

        // reconfigure the input
        cameraSession.beginConfiguration()
        if backCameraOn {
            self.cameraSession.removeInput(self.backInput)
            self.cameraSession.addInput(self.frontInput)
            self.backCameraOn = false
            self.flashlightOn = false
        } else {
            self.cameraSession.removeInput(self.frontInput)
            self.cameraSession.addInput(self.backInput)
            self.backCameraOn = true
        }

        // deal with the connection again for portrait mode
        self.fileOutput.connections.first?.videoOrientation = .portrait
        self.dataOutput.connections.first?.videoOrientation = .portrait

        // commit config
        self.cameraSession.commitConfiguration()
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

    // MARK: - Vision

    func bodyPoseHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedPointsObservation] else { return }

        // Process each observation to find the recognized body pose points.
        observations.forEach { processObservation($0) }
    }
    func processObservation(_ observation: VNRecognizedPointsObservation) {
        // Retrieve all joints.
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .all) else {
            return
        }
        
        //  point keys in a clockwise ordering.
        let keys: [VNHumanBodyPoseObservation.JointName] = [
            VNHumanBodyPoseObservation.JointName.neck,
            VNHumanBodyPoseObservation.JointName.rightShoulder,
            VNHumanBodyPoseObservation.JointName.rightElbow,
            VNHumanBodyPoseObservation.JointName.rightWrist,
            VNHumanBodyPoseObservation.JointName.rightHip,
            VNHumanBodyPoseObservation.JointName.rightKnee,
            VNHumanBodyPoseObservation.JointName.rightAnkle,
            VNHumanBodyPoseObservation.JointName.root,
            VNHumanBodyPoseObservation.JointName.leftAnkle,
            VNHumanBodyPoseObservation.JointName.leftKnee,
            VNHumanBodyPoseObservation.JointName.leftElbow,
            VNHumanBodyPoseObservation.JointName.leftHip,
            VNHumanBodyPoseObservation.JointName.leftWrist,
            VNHumanBodyPoseObservation.JointName.leftElbow,
            VNHumanBodyPoseObservation.JointName.leftShoulder,
            VNHumanBodyPoseObservation.JointName.nose,
            VNHumanBodyPoseObservation.JointName.leftEye,
            VNHumanBodyPoseObservation.JointName.rightEye,
            VNHumanBodyPoseObservation.JointName.leftEar,
            VNHumanBodyPoseObservation.JointName.rightEar,
        ]
        
        var parsedPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        // collect all non-nil points
        for pnt in recognizedPoints {
            let jointName = VNHumanBodyPoseObservation.JointName(rawValue: pnt.key)
            if pnt.value.confidence <= 0 || !keys.contains(jointName) {
                continue
            }
            parsedPoints[jointName] = pnt.value.location
        }
        
        DispatchQueue.main.async {
            self.currentResult = PoseNetResult(points: parsedPoints, imageSize: self.imageBounds)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = sampleBuffer.imageBuffer {
            // Attempt to lock the image buffer to gain access to its memory.
            guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess
            else {
                return
            }

            // Create Core Graphics image placeholder.
            var cgImage: CGImage?

            // Create a Core Graphics bitmap image from the pixel buffer.
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
            
            let uiImage = UIImage(cgImage: cgImage!).withHorizontallyFlippedOrientation()
            
            if self.imageBounds == nil {
                DispatchQueue.main.async {
                    self.imageBounds = uiImage.size
                }
            }

            // Release the image buffer.
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            let requestHandler = VNImageRequestHandler(cgImage: cgImage!)

            // Create a new request to recognize a human body pose.
            let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)

            do {
                // Perform the body pose-detection request.
                try requestHandler.perform([request])
            } catch {
                print("Unable to perform the request: \(error).")
            }

            DispatchQueue.main.async {
                self.currentUIImage = uiImage
            }
        }
    }
}
