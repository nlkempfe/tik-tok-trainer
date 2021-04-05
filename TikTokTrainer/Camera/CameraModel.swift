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
import Promises

class CameraModel: NSObject,
                   ObservableObject {

    @Published var flashlightOn = false
    @Published var isRecording = false
    @Published var isOverlayEnabled = true
    @Published var inErrorState = false
    @Published var isVideoRecorded = false

    @Published var hasPermission = false
    @Published var currentUIImage: UIImage?
    @Published var currentResult: PoseNetResult?
    @Published var currentOrientation: AVCaptureDevice.Position = .front

    // camera feed
    let cameraSession = AVCaptureSession()
    var outputURL: URL!
    var previousSavedURL: URL = URL(string: "placeholder")!
    var imageBounds: CGSize!
    var frontCameraDevice: AVCaptureDevice?
    var backCameraDevice: AVCaptureDevice?
    let videoDataOutput = AVCaptureVideoDataOutput()
    var videoFileOutputWriter: AVAssetWriter?
    var videoFileOutputWriterInput: AVAssetWriterInput?
    var videoFileOutputWriterPool: AVAssetWriterInputPixelBufferAdaptor?
    var startTime: Double = 0

    // queue for processing video data to posenet
    private let posenetDataQueue = DispatchQueue(label: "dev.hunterjarrell.t3.posenetDataQueue")
    private let sessionQueue = DispatchQueue(label: "dev.hunterjarrell.t3.avSessionQueue")

    let approvedJointKeys: Set<VNHumanBodyPoseObservation.JointName> = [
        .neck,
        .rightShoulder,
        .rightElbow,
        .rightWrist,
        .rightHip,
        .rightKnee,
        .rightAnkle,
        .root,
        .leftAnkle,
        .leftKnee,
        .leftElbow,
        .leftHip,
        .leftWrist,
        .leftElbow,
        .leftShoulder,
        .nose,
        .leftEye,
        .rightEye,
        .leftEar,
        .rightEar
    ]

    func checkPermissionsAndSetup(_ permissions: PermissionHandler) {
        permissions.checkCameraPermissions().then(on: sessionQueue) {
            self.setup()
        }.then(on: .main) {
            self.hasPermission = true
        }.catch(on: .main) { err in
            print("Error checking camera permissions. Error: \(err)")
            self.hasPermission = false
        }
    }

    private func setupInput() -> Bool {
        self.frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        self.backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        guard frontCameraDevice != nil && backCameraDevice != nil else {
            print("Could not find a front camera nor back camera.")
            return false
        }

        guard let device = self.currentOrientation == .front ? self.frontCameraDevice : self.backCameraDevice else {
            print("Could not create device for current orientation \(currentOrientation)")
            return false
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("Could not create input for device \(device)")
            return false
        }

        self.cameraSession.inputs.forEach { existingInput in
            self.cameraSession.removeInput(existingInput)
        }

        guard self.cameraSession.canAddInput(input) else {
            print("Cannot add input to session.")
            return false
        }

        self.cameraSession.addInput(input)
        return true
    }

    private func setupOutput() -> Bool {
        self.cameraSession.outputs.forEach { existingOutput in
            self.cameraSession.removeOutput(existingOutput)
        }

        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.posenetDataQueue)

        guard self.cameraSession.canAddOutput(self.videoDataOutput) else {
            print("Cannot add video data output")
            return false
        }
        self.cameraSession.addOutput(self.videoDataOutput)
        self.videoDataOutput.connections.first?.videoOrientation = .portrait

        return true
    }

    func setup() {
        self.sessionQueue.async {
            if self.cameraSession.isRunning {
                self.cameraSession.stopRunning()
            }

            self.cameraSession.beginConfiguration()
            if self.cameraSession.canSetSessionPreset(.high) {
                self.cameraSession.sessionPreset = .high
            }
            self.cameraSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            let inputSuccess = self.setupInput()
            if !inputSuccess {
                self.currentOrientation = self.currentOrientation == .front ? .back : .front
                let secondAttempt = self.setupInput()
                guard secondAttempt else {
                    self.inErrorState = true
                    print("Could not setup camera input")
                    return
                }
            }

            let outputSuccess = self.setupOutput()
            guard outputSuccess else {
                self.inErrorState = true
                print("Could not setup camera output")
                return
            }

            self.cameraSession.commitConfiguration()
            self.cameraSession.startRunning()
            self.setupWriter()
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.isOverlayEnabled = true
            self.inErrorState = false
            self.isVideoRecorded = false
            self.setup()
        }
    }

    func setupWriter() {
        guard !self.isRecording else { return }

        let device = self.currentOrientation == .front ? self.frontCameraDevice : self.backCameraDevice
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
        self.outputURL = self.tempURL()
        do {
            try self.videoFileOutputWriter = AVAssetWriter(outputURL: self.outputURL, fileType: .mov)
            let videoSettings = self.videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
            self.videoFileOutputWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            self.videoFileOutputWriterInput?.expectsMediaDataInRealTime = true
            self.videoFileOutputWriterPool = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoFileOutputWriterInput!,
                                                                                  sourcePixelBufferAttributes: nil)

            if self.videoFileOutputWriter?.canAdd(self.videoFileOutputWriterInput!) ?? false {
                self.videoFileOutputWriter?.add(self.videoFileOutputWriterInput!)
                self.videoFileOutputWriter!.startWriting()
            } else {
                self.isRecording = false
            }

        } catch {
            print("Error setting up video file output. Error: \(error)")
            self.isRecording = false
        }
    }

    // MARK: - Recording
    func startRecording() {
        self.isVideoRecorded = false
        self.isRecording = true
        self.videoFileOutputWriter?.startSession(atSourceTime: .zero)
    }

    func stopRecording(isEarly: Bool) {
        self.isRecording = false

        if self.flashlightOn {
            self.toggleFlash()
        }
        guard !isEarly else {
            DispatchQueue.main.async {
                self.isVideoRecorded = false
            }
            self.setup()
            return
        }

        guard let output = self.videoFileOutputWriter else {
            return
        }

        output.finishWriting {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.outputURL)
            }) { saved, error in
                if saved {
                    DispatchQueue.main.async {
                        self.isVideoRecorded = true
                    }
                    self.previousSavedURL = self.outputURL
                    self.setup()
                } else {
                    DispatchQueue.main.async {
                        self.isVideoRecorded = false
                    }
                    print("Could not save video", error as Any)
                }
            }
        }

        // turn off flashlight if it's on
        if self.flashlightOn {
            self.toggleFlash()
        }
    }

    /// Gets the document directory.
    /// From: https://www.hackingwithswift.com/books/ios-swiftui/writing-data-to-the-documents-directory
    func getDocumentsDirectory() -> URL {
        // find all possible documents directories for this user
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

        // just send back the first one, which ought to be the only one
        return paths[0]
    }

    func tempURL() -> URL? {
        let directory = getDocumentsDirectory()

        let path = directory.appendingPathComponent(NSUUID().uuidString + ".mov")
        return path
    }

    func switchCameraInput() {
        self.currentOrientation = self.currentOrientation == .front ? .back : .front
        self.setup()
    }

    func toggleFlash() {
        self.flashlightOn.toggle()
        guard self.currentOrientation == .back else { return }

        guard let device = self.backCameraDevice else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .on {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 1.0)
            }
            device.unlockForConfiguration()
        } catch {
            print("Could not toggle device flashlight. Error: \(error)")
        }
    }
}

// MARK: - Vision
extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    func emptyPose() {
        DispatchQueue.main.async {
            self.currentResult = PoseNetResult(points: [:], imageSize: nil)
        }
    }

    func bodyPoseHandler(request: VNRequest, error: Error?) {
        guard error == nil else { return emptyPose() }
        guard let observations = request.results as? [VNRecognizedPointsObservation] else { return emptyPose() }
        guard !observations.isEmpty else {return emptyPose()}

        // Process each observation to find the recognized body pose points.
        observations.forEach { processObservation($0) }
    }

    func processObservation(_ observation: VNRecognizedPointsObservation) {
        // Retrieve all joints.
        guard let recognizedPoints = try? observation.recognizedPoints(forGroupKey: .all) else { return emptyPose() }
        guard observation.confidence > 0.6 else { return emptyPose() }

        var parsedPoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        // collect all non-nil points
        for pnt in recognizedPoints {
            let jointName = VNHumanBodyPoseObservation.JointName(rawValue: pnt.key)
            if pnt.value.confidence <= 0 || !approvedJointKeys.contains(jointName) {
                continue
            }
            parsedPoints[jointName] = pnt.value.location
        }

        DispatchQueue.main.async {
            self.currentResult = PoseNetResult(points: parsedPoints, imageSize: nil)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = sampleBuffer.imageBuffer {
            connection.isVideoMirrored = self.currentOrientation == .front
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            // Attempt to lock the image buffer to gain access to its memory.
            guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess
            else {
                return
            }

            // Create Core Graphics image placeholder.
            var cgImage: CGImage?

            // Create a Core Graphics bitmap image from the pixel buffer.
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

            if self.isRecording && self.videoFileOutputWriterInput?.isReadyForMoreMediaData ?? false {
                let time = CMTime(seconds: timestamp - self.startTime - 0.01, preferredTimescale: CMTimeScale(600))
                self.videoFileOutputWriterPool?.append(pixelBuffer, withPresentationTime: time)
            }

            if !self.isRecording {
                self.startTime = timestamp
            }

            let uiImage = UIImage(cgImage: cgImage!)

            // Release the image buffer.
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            if self.isOverlayEnabled {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage!)

                // Create a new request to recognize a human body pose.
                let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)

                do {
                    // Perform the body pose-detection request.
                    try requestHandler.perform([request])
                } catch {
                    print("Unable to perform the request: \(error).")
                    emptyPose()
                }
            } else {
                emptyPose()
            }

            DispatchQueue.main.async {
                self.currentUIImage = uiImage
            }
        }
    }
}
