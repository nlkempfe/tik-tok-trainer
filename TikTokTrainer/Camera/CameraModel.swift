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
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var hasPermission = true
    @Published var backCameraOn = true
    @Published var flashlightOn = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var dataOutput = AVCaptureVideoDataOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var backCamera: AVCaptureDevice!
    @Published var frontCamera: AVCaptureDevice!
    @Published var backInput: AVCaptureInput!
    @Published var frontInput: AVCaptureInput!
    @Published var outputURL: URL!
    @Published var isRecording = false
    @Published var view = UIView(frame: UIScreen.main.bounds)
    
    var boundsWidth: CGFloat!
    var boundsHeight: CGFloat!
    
    var drawn = false
    
    var imagePoints: [CGPoint]!
    
    //metal
    var metalDevice : MTLDevice!
    var metalCommandQueue : MTLCommandQueue!
    
    //core image
    var ciContext : CIContext!
    
    var currentCIImage : CIImage?
    
    let fadeFilter = CIFilter(name: "CIPhotoEffectFade")
    let sepiaFilter = CIFilter(name: "CISepiaTone")
    
    let mtkView = MTKView()
    
    private var currentFrame: CGImage!
    
    private let sessionQueue = DispatchQueue(
        label: "T3.cameraQueue")


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

        self.dataOutput.alwaysDiscardsLateVideoFrames = true
        self.dataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        // TODO: setup file capture output
        // self.session.addOutput(self.output)
        
        self.session.addOutput(dataOutput)
        
        self.dataOutput.connections.first?.videoOrientation = .portrait
        

        // commit configuration
        self.session.commitConfiguration()

        // start session
        self.session.startRunning()

    }
    
    //MARK:- Metal
    func setupMetal(){
        //fetch the default gpu of the device (only one on iOS devices)
        metalDevice = MTLCreateSystemDefaultDevice()
        
        //tell our MTKView which gpu to use
        mtkView.device = metalDevice
        
        //tell our MTKView to use explicit drawing meaning we have to call .draw() on it
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        //create a command queue to be able to send down instructions to the GPU
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        //conform to our MTKView's delegate
        mtkView.delegate = self
        
        //let it's drawable texture be writen to
        mtkView.framebufferOnly = false
        
        mtkView.frame = UIScreen.main.bounds
        boundsWidth = UIScreen.main.bounds.width
        boundsHeight = UIScreen.main.bounds.height

        print(mtkView.frame.size)
        mtkView.enableSetNeedsDisplay = true
        
        setupCoreImage()
    }
    
    //MARK:- Core Image
    func setupCoreImage(){
        ciContext = CIContext(mtlDevice: metalDevice)
        setupFilters()
        setUp()
    }
    
    //MARK: -TODO: Draw Points on Image
    func setupFilters(){
        sepiaFilter?.setValue(NSNumber(value: 1), forKeyPath: "inputIntensity")
    }
    
    func applyFilters(inputImage image: CIImage) -> CIImage? {
        var filteredImage : CIImage?
        
        //apply filters
        sepiaFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        filteredImage = sepiaFilter?.outputImage
              
        fadeFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        filteredImage = fadeFilter?.outputImage
        return filteredImage
    }
    
    // MARK: - Recording
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

    // MARK: - Camera Toggles
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
            self.dataOutput.connections.first?.videoOrientation = .portrait

           // commit config
            self.session.commitConfiguration()
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
        // Retrieve all torso points.
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .bodyLandmarkRegionKeyTorso) else {
            return
        }
        
        // Torso point keys in a clockwise ordering.
        let torsoKeys: [VNRecognizedPointKey] = [
            .bodyLandmarkKeyNeck,
            .bodyLandmarkKeyRightShoulder,
            .bodyLandmarkKeyRightHip,
            .bodyLandmarkKeyRoot,
            .bodyLandmarkKeyLeftHip,
            .bodyLandmarkKeyLeftShoulder
        ]
        
        // Retrieve the CGPoints containing the normalized X and Y coordinates.
        imagePoints = torsoKeys.compactMap {
            guard let point = recognizedPoints[$0], point.confidence > 0 else { return nil }
            
            // Translate the point from normalized-coordinates to image coordinates.
            return VNImagePointForNormalizedPoint(point.location,
                                                  Int(boundsWidth),
                                                  Int(boundsHeight))
        }
        
        // Draw the points onscreen.
//        for i in imagePoints {
//            print(i)
//        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        
        // TODO: Draw points on top of this image
        guard let filteredCIImage = applyFilters(inputImage: ciImage) else {
            return
        }

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

            // Release the image buffer.
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            let requestHandler = VNImageRequestHandler(cgImage: cgImage!)


            // Create a new request to recognize a human body pose.
            let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)

            self.currentFrame = cgImage

            do {
                // Perform the body pose-detection request.
                try requestHandler.perform([request])
            } catch {
                print("Unable to perform the request: \(error).")
            }
            
            if imagePoints != nil {
                var testCgImage = self.ciContext.createCGImage(filteredCIImage, from: filteredCIImage.extent)
                self.currentCIImage = CIImage(image: drawRectangleOnImage(image: UIImage(cgImage: testCgImage!)))
                drawn.toggle()
            }
            else {
                self.currentCIImage = filteredCIImage
            }
            
            mtkView.draw()

//            DispatchQueue.main.sync {
//                delegate.videoCapture(self, didCaptureFrame: image)
//            }
        }
    }
    
    // MARK: - Testing stuff
    func drawRectangleOnImage(image: UIImage) -> UIImage {
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContext(imageSize)
        let context = UIGraphicsGetCurrentContext()
        for i in imagePoints {
        image.draw(at: CGPoint.zero)
        let rectangle = CGRect(x: i.x, y: i.y, width: 20, height: 20)

            context!.setFillColor(UIColor.green.cgColor)
            context!.addRect(rectangle)
            
        }
        context!.drawPath(using: .fill)
        
        imagePoints = nil

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
}

extension CameraModel : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //tells us the drawable's size has changed
    }
    
    func draw(in view: MTKView) {
        //create command buffer for ciContext to use to encode it's rendering instructions to our GPU
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }
        
        //make sure we actually have a ciImage to work with
        guard let ciImage = currentCIImage else {
            return
        }
        
        //make sure the current drawable object for this metal view is available (it's not in use by the previous draw cycle)
        guard let currentDrawable = view.currentDrawable else {
            return
        }

        //make sure frame is centered on screen
        let heightOfciImage = ciImage.extent.height
        let heightOfDrawable = view.drawableSize.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
        
        //render into the metal texture
        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                   commandBuffer: commandBuffer,
                          bounds: CGRect(origin: CGPoint(x: 0, y: -yOffsetFromBottom), size: view.drawableSize),
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        //register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        //commit the command to the queue so it executes
        commandBuffer.commit()
    }
}
