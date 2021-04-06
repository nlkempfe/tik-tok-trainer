//
//  PermissionViewController.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 1/30/21.
//

import Foundation
import SwiftUI
import Photos
import AVKit
import Promises

class PermissionHandler: ObservableObject {

    @Published var hasCameraPermissions = false
    @Published var hasPhotosPermissions = false

    enum CameraPermissionError: Error {
        case userRejected
        case unknownError
    }

    enum PhotosPermissionError: Error {
        case userRejected
        case unknownError
    }

    /// Updates the Camera Permission Published value. This needs to be done on the main thread so this function abstracts that away
    func updateCameraPermissions(_ value: Bool) {
        DispatchQueue.main.async {
            self.hasCameraPermissions = value
        }
    }

    func checkCameraPermissions() -> Promise<Void> {
        return Promise { fullfill, reject in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.updateCameraPermissions(true)
                return fullfill(())
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { (status) in
                    if status {
                        self.updateCameraPermissions(true)
                        return fullfill(())
                    } else {
                        print("User denied access to Camera")
                        self.updateCameraPermissions(false)
                        return reject(CameraPermissionError.userRejected)
                    }
                }
            case .denied:
                print("Camera permissions denied")
                self.updateCameraPermissions(false)
                reject(CameraPermissionError.userRejected)
            default:
                print("Unknown Camera Authorization Status!")
                self.updateCameraPermissions(false)
                reject(CameraPermissionError.unknownError)
            }
        }
    }

    /// Updates the Photos Permission Published value. This needs to be done on the main thread so this function abstracts that away
    func updatePhotosPermissions(_ value: Bool) {
        DispatchQueue.main.async {
            self.hasPhotosPermissions = value
        }
    }

    func checkPhotosPermissions() -> Promise<Void> {
        return Promise {fullfill, reject in
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
                self.updatePhotosPermissions(true)
                return fullfill(())
            }

            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .notDetermined:
                    // The user hasn't determined this app's access.
                    // Uh I'm not sure how this would be the case ever since this is in a requestAuthorization call
                    print("Requested Photo Authorization and got notDetermined PHAuthorizationStatus.")
                    return reject(PhotosPermissionError.unknownError)
                case .restricted:
                    // The system restricted this app's access.
                    // If this happens we have other problems
                    print("Requested Photo Authorization and got restricted PHAuthorizationStatus.")
                    return reject(PhotosPermissionError.unknownError)
                case .denied:
                    // The user explicitly denied this app's access.
                    return reject(PhotosPermissionError.userRejected)
                case .authorized:
                    // The user authorized this app to access Photos data.
                    return fullfill(())
                case .limited:
                    // The user authorized this app for limited Photos access.
                    return fullfill(())
                @unknown default:
                    print("Error unhandled status for requesting Photo Authorization")
                    return reject(PhotosPermissionError.unknownError)
                }
            }
        }
    }

    /// Opens the permissions settings for the app
    static func openPermissionsSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
