//
//  NoCameraPermissionsView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 4/4/21.
//

import SwiftUI

struct NoCameraPermissionsView: View {
    var body: some View {
        HStack {
            Button(StringConstants.permissionsCamera, action: PermissionHandler.openPermissionsSettings)
        }
    }
}

struct NoCameraPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        NoCameraPermissionsView()
    }
}
