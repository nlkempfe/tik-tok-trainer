//
//  PermissionViewController.swift
//  TikTokTrainer
//
//  Created by David Sadowsky on 1/30/21.
//

import Foundation
import SwiftUI

class PermissionModel: ObservableObject {
    func openPermissionsSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}