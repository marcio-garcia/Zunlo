//
//  RemoteBackgroundImage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import SwiftUI

struct RemoteBackgroundImage: View {
    let lowResName: String
    let remoteName: String?

    @State private var remoteImage: UIImage?

    var body: some View {
        ZStack {
            Image(lowResName)
                .resizable()
                .scaledToFill()
                .opacity(remoteImage == nil ? 1 : 0) // hide when loaded

            if let uiImage = remoteImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
        }
//        .task(id: remoteName) {
//            await loadRemoteImage()
//        }
    }

    private func loadRemoteImage() async {
        guard remoteImage == nil, let name = remoteName else { return } // already fetched
        
        let remote = RemoteStorageService(envConfig: EnvConfig.shared)
        let data = await remote.downloadImage(fileName: name)
        if let data, let image = UIImage(data: data) {
            remoteImage = image
        }
    }
}
