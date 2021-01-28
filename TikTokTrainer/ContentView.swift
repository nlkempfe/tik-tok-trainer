//
//  ContentView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 1/13/21.
//

import SwiftUI
import AVFoundation

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
                        Button(action: {camera.stopRecord(flashlight: flashlight)}, label: {
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
                        Button(action: {camera.startRecord(flashlight: flashlight)}, label: {
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

class CameraModel: NSObject, ObservableObject {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var backCameraOn = true
    @Published var output = AVCaptureVideoDataOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    @Published var backCamera : AVCaptureDevice!
    @Published var frontCamera : AVCaptureDevice!
    @Published var backInput : AVCaptureInput!
    @Published var frontInput : AVCaptureInput!
    
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
                    
        //setup inputs
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            self.backCamera = device
        } else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }
                    
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            self.frontCamera = device
        } else {
            fatalError("no front camera")
        }
    
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            fatalError("could not create input device from back camera")
        }
        backInput = bInput
        if !session.canAddInput(backInput) {
            fatalError("could not add back camera input to capture session")
        }
                    
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        if !session.canAddInput(frontInput) {
            fatalError("could not add front camera input to capture session")
        }
        
        self.session.addInput(backInput)
            
        //setup outputs
        self.session.addOutput(self.output)
                    
        //commit configuration
        self.session.commitConfiguration()

    }
    
    func setupOutputs(){
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        output.setSampleBufferDelegate(self, queue: videoQueue)
            
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            fatalError("could not add video output")
        }
        //deal with the orientation
        output.connections.first?.videoOrientation = .portrait
    }
    
    func startRecord(flashlight: FlashlightModel) {
        self.isTaken.toggle()
        if(flashlight.isOn) {
            flashlight.toggleFlash()
        }
    }
    
    func stopRecord(flashlight: FlashlightModel) {
        self.isTaken.toggle()
        if(flashlight.isOn) {
            flashlight.toggleFlash()
        }
        
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
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
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
        
        camera.session.startRunning()
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
