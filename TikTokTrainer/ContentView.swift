//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 1/13/21.
//

import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    @StateObject var flashlight = FlashlightModel()
    var body: some View {
        ZStack {
            
            // Going to be camera preview
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                    HStack {
                        Spacer()
                        if !camera.isTaken {
                            VStack {
                                Button(action: {camera.switchCameraInput()}, label: {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .foregroundColor(.white)
                                        .padding()
                                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                                })
                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                .padding(.trailing, 10)
                                if !flashlight.isOn {
                                    Button(action: {flashlight.isOn.toggle()}, label: {
                                        Image(systemName: "bolt")
                                            .foregroundColor(.white)
                                            .padding()
                                            .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                                        })
                                        .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                        .padding(.trailing, 10)
                                    }
                                else {
                                    Button(action: {flashlight.isOn.toggle()}, label: {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.white)
                                            .padding()
                                            .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                                        })
                                        .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                        .padding(.trailing, 10)
                                }
                            }
                        }
                    }
                Spacer()
                HStack {
                    if camera.isTaken {
                        Button(action: {camera.stopRecord()}, label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 65, height: 65)
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    }
                    else {
                        Button(action: {camera.startRecord()}, label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    }
                }
                .frame(height: 75)
            }
        }
        .onAppear(perform: {
            camera.Check()
        })
    }
}

class CameraModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate, AVCaptureMetadataOutputObjectsDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var backCameraOn = true
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    @Published var backCamera : AVCaptureDevice!
    @Published var frontCamera : AVCaptureDevice!
    @Published var backInput : AVCaptureInput!
    @Published var frontInput : AVCaptureInput!
    @Published var outputURL: URL!
    @Published var isRecording = false
    @Published var view = UIView(frame: UIScreen.main.bounds)
    
    func Check() {
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
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    func setUp() {
        //start configuration
        self.session.beginConfiguration()
                    
        //session specific configuration
        if self.session.canSetSessionPreset(.photo) {
            self.session.sessionPreset = .photo
        }
        self.session.automaticallyConfiguresCaptureDeviceForWideColor = true
        self.session.sessionPreset = AVCaptureSession.Preset.high
                    
        //setup inputs
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            self.backCamera = device
        } else {
            // Change this for CICD
            fatalError("no back camera")
        }
                    
        //get front camera
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
            
        //setup output
        self.session.addOutput(self.output)
                    
        //commit configuration
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
        }
        else {
            stopRecord()
        }
    }
    
    func stopRecord() {
        if self.output.isRecording == true {
            self.output.stopRecording()
        }
        self.isTaken.toggle()
        saveVideo()
    }
    
    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    func saveVideo() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.outputURL)
        })
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            
            _ = outputURL as URL
            
        }
        outputURL = nil
    }
    
    func switchCameraInput(){
           //don't let user spam the button, fun for the user, not fun for performance
           
           //reconfigure the input
           session.beginConfiguration()
           if backCameraOn {
                session.removeInput(self.backInput)
                session.addInput(self.frontInput)
                backCameraOn = false
           } else {
                session.removeInput(self.frontInput)
                session.addInput(self.backInput)
                backCameraOn = true
           }
           
           //deal with the connection again for portrait mode
           output.connections.first?.videoOrientation = .portrait
           
           //commit config
           session.commitConfiguration()
       }
    
    func setupPreviewLayer() {
        self.preview = AVCaptureVideoPreviewLayer(session: self.session)
        self.preview.frame = view.frame
        self.preview.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.preview)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera : CameraModel
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)

        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
}

class FlashlightModel: ObservableObject {
    @Published var isOn = false
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
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
    }
}
