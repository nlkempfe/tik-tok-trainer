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

    @Binding var uploadedVideo: SelectedVideo?
    @Binding var isVideoPickerOpen: Bool
    @Binding var isLandscape: Bool

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

                DispatchQueue.main.async {
                    let thumbnailImage = UIImage(cgImage: imageRef!)
                    if thumbnailImage.size.width > thumbnailImage.size.height {
                        self.parent.isLandscape = true
                    } else {
                        self.parent.isLandscape = false
                    }
                    let uploadedVideoDuration = CMTimeGetSeconds(AVAsset(url: videoURL).duration)
                    self.parent.uploadedVideo = SelectedVideo(videoURL: videoURL, thumbnail: thumbnailImage, videoDuration: uploadedVideoDuration)
                    self.parent.isVideoPickerOpen = false
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
