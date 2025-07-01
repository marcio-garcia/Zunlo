//
//  NetworkClient.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

final class NetworkClient {
    private let session: URLSession
    private let config: SupabaseConfig
    
    var authToken: String?
    
    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }
    
    func sendRequest(path: String,
                     method: String,
                     query: [String: String]? = nil,
                     body: Data? = nil,
                     additionalHeaders: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        var url = config.baseURL.appendingPathComponent(path)
        if let query = query, !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(config.anonKey)", forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        additionalHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}
