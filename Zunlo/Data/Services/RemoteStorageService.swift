//
//  RemoteStorageService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/2/25.
//

import Foundation
import Supabase

final class RemoteStorageService {
    private let supabase: SupabaseClient
    
    init(envConfig: EnvConfig) {
        supabase = SupabaseClient(supabaseURL: URL(string: envConfig.apiBaseUrl)!,
                                  supabaseKey: envConfig.apiKey)
    }
    
    func uploadImage(_ imageData: Data, fileName: String) async {
        do {
            let bucket = supabase.storage.from("images")

            try await bucket.upload(
                fileName,
                data: imageData,
                options: FileOptions(contentType: "image/heic")
            )

            print("Image uploaded")
        } catch {
            print("Upload failed: \(error)")
        }
    }
    
    func downloadImage(fileName: String) async -> Data? {
        do {
            let bucket = supabase.storage.from("images")
            let signedURL = try await bucket.createSignedURL(path: "private/\(fileName)", expiresIn: 3600)
            let (data, _) = try await URLSession.shared.data(from: signedURL)
            return data
        } catch {
            print("Download failed: \(error.localizedDescription)")
            return nil
        }
    }
}
