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
            VNHumanBodyPoseObservation.JointName.neck.rawValue,
            VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue,
            VNHumanBodyPoseObservation.JointName.rightElbow.rawValue,
            VNHumanBodyPoseObservation.JointName.rightWrist.rawValue,
            VNHumanBodyPoseObservation.JointName.rightHip.rawValue,
            VNHumanBodyPoseObservation.JointName.rightKnee.rawValue,
            VNHumanBodyPoseObservation.JointName.rightAnkle.rawValue,
            VNHumanBodyPoseObservation.JointName.root.rawValue,
            VNHumanBodyPoseObservation.JointName.leftAnkle.rawValue,
            VNHumanBodyPoseObservation.JointName.leftKnee.rawValue,
            VNHumanBodyPoseObservation.JointName.leftElbow.rawValue,
            VNHumanBodyPoseObservation.JointName.leftHip.rawValue,
            VNHumanBodyPoseObservation.JointName.leftWrist.rawValue,
            VNHumanBodyPoseObservation.JointName.leftElbow.rawValue,
            VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue,
            VNHumanBodyPoseObservation.JointName.nose.rawValue,
            VNHumanBodyPoseObservation.JointName.leftEye.rawValue,
            VNHumanBodyPoseObservation.JointName.rightEye.rawValue,
            VNHumanBodyPoseObservation.JointName.leftEar.rawValue,
            VNHumanBodyPoseObservation.JointName.rightEar.rawValue,
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
    
    func drawLine(context: CGContext, firstPoint: CGPoint?, secondPoint: CGPoint?) {
        if firstPoint != nil && secondPoint != nil {
            context.addLines(between: [CGPoint(x: firstPoint!.x, y: self.imageBounds.height - firstPoint!.y), CGPoint(x: secondPoint!.x, y: self.imageBounds.height - secondPoint!.y)])
            context.drawPath(using: .stroke)
        }
    }
    
    func drawPose(image: UIImage) -> UIImage {
        // configure context
        let imageSize = image.size
        UIGraphicsBeginImageContext(imageSize)
        let context = UIGraphicsGetCurrentContext()!
        
        // draw all joints
        context.setFillColor(UIColor.green.cgColor)
        for i in imagePoints {
            image.draw(at: CGPoint.zero)
            let rectangle = CGRect(x: i.value.x, y: self.imageBounds.height - i.value.y, width: 20, height: 20)
            context.addEllipse(in: rectangle)
        }
        context.drawPath(using: .fill)
        
        // connect joints
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(3)
        
        let drawingPairs = [
            ("neck_1_joint", "right_shoulder_1_joint"),
            ("neck_1_joint", "left_shoulder_1_joint"),
            ("left_forearm_joint", "left_shoulder_1_joint"),
            ("left_forearm_joint", "left_hand_joint"),
            ("right_forearm_joint", "right_shoulder_1_joint"),
            ("right_forearm_joint", "right_hand_joint"),
            ("root", "left_upLeg_joint"),
            ("root", "neck_1_joint"),
            ("left_leg_joint", "left_upLeg_joint"),
            ("left_leg_joint", "left_foot_joint"),
            ("root", "right_upLeg_joint"),
            ("right_leg_joint", "right_upLeg_joint"),
            ("right_leg_joint", "right_foot_joint"),
            ("neck_1_joint", "head_joint"),
            ("left_eye_joint", "head_joint"),
            ("left_eye_joint", "left_ear_joint"),
            ("right_eye_joint", "head_joint"),
            ("right_eye_joint", "right_ear_joint"),
        ]
        
        for (firstPoint, secondPoint) in drawingPairs {
            drawLine(context: context, firstPoint: imagePoints[firstPoint], secondPoint: imagePoints[secondPoint])
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
        
        // TODO: fix screen size scaling on max devices (temporary fix)
        view.drawableSize = ciImage.extent.size
        
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
