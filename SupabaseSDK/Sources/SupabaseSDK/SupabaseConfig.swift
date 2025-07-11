//
//  SupabaseConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public struct SupabaseConfig: Sendable {
    public let anonKey: String
    public let baseURL: URL
    public let functionsBaseURL: URL?
    
    public init(anonKey: String, baseURL: URL, functionsBaseURL: URL?) {
        self.anonKey = anonKey
        self.baseURL = baseURL
        self.functionsBaseURL = functionsBaseURL
    }
}
