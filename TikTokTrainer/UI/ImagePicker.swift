//
//  UploadedVideoView.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 2/20/21.
//

import Foundation
import SwiftUI
import UIKit
import AVKit
import Photos
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode

    @Binding var uploadedVideoURL: URL
    @Binding var isVideoPickerOpen: Bool
    @Binding var isVideoUploaded: Bool
    @Binding var thumbnailImage: UIImage
    @Binding var uploadedVideoDuration: Double

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let videoProvider = results.first?.itemProvider else {
                return
            }
            
            let date = Date().timeIntervalSince1970

            videoProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { (url, err) in
                guard err == nil else {
                    print("Error loading file from videoPicker. Error: \(err!)")
                    return
                }
                guard let url = url else { return }
                
                

                let fileName = "\(Date().timeIntervalSince1970).\(url.pathExtension)"
                let videoURL = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
                try? FileManager.default.copyItem(at: url, to: videoURL)

                let asset = AVAsset(url: videoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTimeMake(value: 1, timescale: 1)
                var imageRef = UIImage().cgImage
                do {
                    imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                } catch {
                    print("imageGenerator could not copy image from AVAsset", error)
                }
                
                print(Date().timeIntervalSince1970 - date)

                DispatchQueue.main.async {
                    self.parent.thumbnailImage = UIImage(cgImage: imageRef!)
                    self.parent.uploadedVideoURL = videoURL
                    self.parent.uploadedVideoDuration = CMTimeGetSeconds(AVAsset(url: self.parent.uploadedVideoURL).duration)
                    self.parent.isVideoPickerOpen = false
                    self.parent.isVideoUploaded = true
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()

        configuration.selectionLimit = 1
        configuration.filter = .videos
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // leave this empty
    }
}
