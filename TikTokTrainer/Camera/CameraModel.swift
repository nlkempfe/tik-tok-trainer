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
    @Published var view = UIView(frame: UIScreen.main.bounds)
    @Published var imageBounds: CGSize!

    // joint data
    var imagePoints: [String: CGPoint] = [:]

    // metal
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    let mtkView = MTKView()

    // core image
    var ciContext: CIContext!
    var currentCIImage: CIImage?

    // queue for processing video data to posenet
    private let posenetDataQueue = DispatchQueue(
        label: "T3.posenetDataQueue")

    func check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupMetal()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    self.setupMetal()
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
        //self.cameraSession.addOutput(self.fileOutput)
        self.cameraSession.addOutput(self.dataOutput)

        self.dataOutput.connections.first?.videoOrientation = .portrait

        // commit configuration
        self.cameraSession.commitConfiguration()

        // start session
        self.cameraSession.startRunning()

    }

    // MARK: - Metal
    func setupMetal() {
        // fetch the default gpu of the device (only one on iOS devices)
        metalDevice = MTLCreateSystemDefaultDevice()

        // tell our MTKView which gpu to use
        mtkView.device = metalDevice

        // tell our MTKView to use explicit drawing meaning we have to call .draw() on it
        mtkView.isPaused = true

        // create a command queue to be able to send down instructions to the GPU
        metalCommandQueue = metalDevice.makeCommandQueue()

        // conform to our MTKView's delegate
        mtkView.delegate = self

        // let it's drawable texture be writen to
        mtkView.framebufferOnly = false

        // setting this so that we dont *need* to draw on the image (when there's no points to draw)
        mtkView.enableSetNeedsDisplay = true
        
        // fixes bounds issues for iphone max models
        mtkView.contentScaleFactor = UIScreen.main.nativeScale

        setupCoreImage()
    }

    // MARK: - Core Image
    func setupCoreImage() {
        // init core image context (used for camera feed + rendering drawing)
        ciContext = CIContext(mtlDevice: metalDevice)
        setUp()
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
                self.view.transform = CGAffineTransform(scaleX: -1, y: 1)
           } else {
                self.cameraSession.removeInput(self.frontInput)
                self.cameraSession.addInput(self.backInput)
                self.backCameraOn = true
                self.view.transform = CGAffineTransform(scaleX: 1, y: 1)
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
        let keys: [VNRecognizedPointKey] = [
            .bodyLandmarkKeyNeck,
            .bodyLandmarkKeyRightShoulder,
            .bodyLandmarkKeyRightElbow,
            .bodyLandmarkKeyRightWrist,
            .bodyLandmarkKeyRightHip,
            .bodyLandmarkKeyRightKnee,
            .bodyLandmarkKeyRightAnkle,
            .bodyLandmarkKeyRoot,
            .bodyLandmarkKeyLeftAnkle,
            .bodyLandmarkKeyLeftKnee,
            .bodyLandmarkKeyLeftElbow,
            .bodyLandmarkKeyLeftHip,
            .bodyLandmarkKeyLeftWrist,
            .bodyLandmarkKeyLeftElbow,
            .bodyLandmarkKeyLeftShoulder,
            .bodyLandmarkKeyNose,
            .bodyLandmarkKeyLeftEye,
            .bodyLandmarkKeyRightEye,
            .bodyLandmarkKeyLeftEar,
            .bodyLandmarkKeyRightEar
        ]

        // collect all non-nil points
        for i in recognizedPoints {
            if i.value.confidence <= 0 || !keys.contains(i.key) {
                continue
            }
            imagePoints[i.key.rawValue] = VNImagePointForNormalizedPoint(i.value.location, Int(self.imageBounds.width), Int(self.imageBounds.height))
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)

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
            
            if self.imageBounds == nil {
                DispatchQueue.main.async {
                    self.imageBounds = UIImage(cgImage: cgImage!).size
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

            // Draw points over image if joints are recognized, set image to default camera feed otherwise
            if imagePoints.count > 0 {
                self.currentCIImage = CIImage(image: drawPose(image: UIImage(cgImage: self.ciContext.createCGImage(ciImage, from: ciImage.extent)!)))
            } else {
                self.currentCIImage = ciImage
            }

            // render metal view
            mtkView.draw()

        }
    }

    // MARK: - Posenet Overlay
    func drawPose(image: UIImage) -> UIImage {

        // configure context
        let imageSize = image.size
        UIGraphicsBeginImageContext(imageSize)
        let context = UIGraphicsGetCurrentContext()

        // draw all joints
        context!.setFillColor(UIColor.green.cgColor)
        for i in imagePoints {
            image.draw(at: CGPoint.zero)
            let rectangle = CGRect(x: i.value.x, y: self.imageBounds.height - i.value.y, width: 20, height: 20)
            context!.addEllipse(in: rectangle)
        }
        context!.drawPath(using: .fill)

        // connect joints
        context!.setStrokeColor(UIColor.green.cgColor)
        context!.setLineWidth(3)
        if imagePoints["neck_1_joint"] != nil && imagePoints["right_shoulder_1_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["neck_1_joint"]!.x, y: self.imageBounds.height - imagePoints["neck_1_joint"]!.y), CGPoint(x: imagePoints["right_shoulder_1_joint"]!.x, y: self.imageBounds.height - imagePoints["right_shoulder_1_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["neck_1_joint"] != nil && imagePoints["left_shoulder_1_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["neck_1_joint"]!.x, y: self.imageBounds.height - imagePoints["neck_1_joint"]!.y), CGPoint(x: imagePoints["left_shoulder_1_joint"]!.x, y: self.imageBounds.height - imagePoints["left_shoulder_1_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_forearm_joint"] != nil && imagePoints["left_shoulder_1_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_forearm_joint"]!.x, y: self.imageBounds.height - imagePoints["left_forearm_joint"]!.y), CGPoint(x: imagePoints["left_shoulder_1_joint"]!.x, y: self.imageBounds.height - imagePoints["left_shoulder_1_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_forearm_joint"] != nil && imagePoints["left_hand_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_forearm_joint"]!.x, y: self.imageBounds.height - imagePoints["left_forearm_joint"]!.y), CGPoint(x: imagePoints["left_hand_joint"]!.x, y: self.imageBounds.height - imagePoints["left_hand_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_forearm_joint"] != nil && imagePoints["right_shoulder_1_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_forearm_joint"]!.x, y: self.imageBounds.height - imagePoints["right_forearm_joint"]!.y), CGPoint(x: imagePoints["right_shoulder_1_joint"]!.x, y: self.imageBounds.height - imagePoints["right_shoulder_1_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_forearm_joint"] != nil && imagePoints["right_hand_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_forearm_joint"]!.x, y: self.imageBounds.height - imagePoints["right_forearm_joint"]!.y), CGPoint(x: imagePoints["right_hand_joint"]!.x, y: self.imageBounds.height - imagePoints["right_hand_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["root"] != nil && imagePoints["left_upLeg_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["root"]!.x, y: self.imageBounds.height - imagePoints["root"]!.y), CGPoint(x: imagePoints["left_upLeg_joint"]!.x, y: self.imageBounds.height - imagePoints["left_upLeg_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["root"] != nil && imagePoints["neck_1_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["root"]!.x, y: self.imageBounds.height - imagePoints["root"]!.y), CGPoint(x: imagePoints["neck_1_joint"]!.x, y: self.imageBounds.height - imagePoints["neck_1_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_leg_joint"] != nil && imagePoints["left_upLeg_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_leg_joint"]!.x, y: self.imageBounds.height - imagePoints["left_leg_joint"]!.y), CGPoint(x: imagePoints["left_upLeg_joint"]!.x, y: self.imageBounds.height - imagePoints["left_upLeg_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_leg_joint"] != nil && imagePoints["left_foot_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_leg_joint"]!.x, y: self.imageBounds.height - imagePoints["left_leg_joint"]!.y), CGPoint(x: imagePoints["left_foot_joint"]!.x, y: self.imageBounds.height - imagePoints["left_foot_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["root"] != nil && imagePoints["right_upLeg_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["root"]!.x, y: self.imageBounds.height - imagePoints["root"]!.y), CGPoint(x: imagePoints["right_upLeg_joint"]!.x, y: self.imageBounds.height - imagePoints["right_upLeg_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_leg_joint"] != nil && imagePoints["right_upLeg_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_leg_joint"]!.x, y: self.imageBounds.height - imagePoints["right_leg_joint"]!.y), CGPoint(x: imagePoints["right_upLeg_joint"]!.x, y: self.imageBounds.height - imagePoints["right_upLeg_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_leg_joint"] != nil && imagePoints["right_foot_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_leg_joint"]!.x, y: self.imageBounds.height - imagePoints["right_leg_joint"]!.y), CGPoint(x: imagePoints["right_foot_joint"]!.x, y: self.imageBounds.height - imagePoints["right_foot_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["neck_1_joint"] != nil && imagePoints["head_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["neck_1_joint"]!.x, y: self.imageBounds.height - imagePoints["neck_1_joint"]!.y), CGPoint(x: imagePoints["head_joint"]!.x, y: self.imageBounds.height - imagePoints["head_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_eye_joint"] != nil && imagePoints["head_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_eye_joint"]!.x, y: self.imageBounds.height - imagePoints["left_eye_joint"]!.y), CGPoint(x: imagePoints["head_joint"]!.x, y: self.imageBounds.height - imagePoints["head_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["left_eye_joint"] != nil && imagePoints["left_ear_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["left_eye_joint"]!.x, y: self.imageBounds.height - imagePoints["left_eye_joint"]!.y), CGPoint(x: imagePoints["left_ear_joint"]!.x, y: self.imageBounds.height - imagePoints["left_ear_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_eye_joint"] != nil && imagePoints["head_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_eye_joint"]!.x, y: self.imageBounds.height - imagePoints["right_eye_joint"]!.y), CGPoint(x: imagePoints["head_joint"]!.x, y: self.imageBounds.height - imagePoints["head_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        if imagePoints["right_eye_joint"] != nil && imagePoints["right_ear_joint"] != nil {
            context!.addLines(between: [CGPoint(x: imagePoints["right_eye_joint"]!.x, y: self.imageBounds.height - imagePoints["right_eye_joint"]!.y), CGPoint(x: imagePoints["right_ear_joint"]!.x, y: self.imageBounds.height - imagePoints["right_ear_joint"]!.y)])
            context!.drawPath(using: .stroke)
        }

        // remove points after drawn
        imagePoints.removeAll()

        // return new image with joints/connections rendered
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
}

// MARK: - MTK Protocols

extension CameraModel: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // tells us the drawable's size has changed
    }

    func draw(in view: MTKView) {

        // create command buffer for ciContext to use to encode it's rendering instructions to our GPU
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }

        // make sure we actually have a ciImage to work with
        guard let ciImage = currentCIImage else {
            return
        }

        // make sure the current drawable object for this metal view is available (it's not in use by the previous draw cycle)
        guard let currentDrawable = view.currentDrawable else {
            return
        }

        // make sure frame is centered on screen
        let heightOfciImage = ciImage.extent.height
        let heightOfDrawable = view.drawableSize.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2

        // render into the metal texture
        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                   commandBuffer: commandBuffer,
                          bounds: CGRect(origin: CGPoint(x: 0, y: -yOffsetFromBottom), size: view.drawableSize),
                      colorSpace: CGColorSpaceCreateDeviceRGB())

        // register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)

        // commit the command to the queue so it executes
        commandBuffer.commit()
    }
}
