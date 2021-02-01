//
//  CameraPreview.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 1/29/21.
//

import Foundation
import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> some UIView {
        camera.view.backgroundColor = .black
        camera.mtkView.translatesAutoresizingMaskIntoConstraints = false
        camera.view.addSubview(camera.mtkView)

        NSLayoutConstraint.activate([
            camera.mtkView.bottomAnchor.constraint(equalTo: camera.view.bottomAnchor),
            camera.mtkView.trailingAnchor.constraint(equalTo: camera.view.trailingAnchor),
            camera.mtkView.leadingAnchor.constraint(equalTo: camera.view.leadingAnchor),
            camera.mtkView.topAnchor.constraint(equalTo: camera.view.topAnchor)
        ])

        return camera.view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {

    }
}
