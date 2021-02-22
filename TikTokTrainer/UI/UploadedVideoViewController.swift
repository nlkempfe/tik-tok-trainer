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

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var uploadedVideoURL: URL
    @Binding var isVideoPickerOpen: Bool
    @Binding var isVideoUploaded: Bool
    @Binding var thumbnailImage: UIImage
    @Binding var duration: Double

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                self.parent.uploadedVideoURL = videoURL
                let asset = AVAsset(url: videoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTimeMake(value: 1, timescale: 1)
                var imageRef = UIImage().cgImage
                do {
                    imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                } catch {
                    print(error)
                }
                self.parent.thumbnailImage = UIImage(cgImage: imageRef!)
            }
            self.parent.duration = CMTimeGetSeconds(AVAsset(url: self.parent.uploadedVideoURL).duration)
            self.parent.isVideoPickerOpen = false
            self.parent.isVideoUploaded = true

            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // leave this empty
    }
}
