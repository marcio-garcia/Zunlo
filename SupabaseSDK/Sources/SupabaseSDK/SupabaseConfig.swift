//
//  SupabaseConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public struct SupabaseConfig {
    public let anonKey: String
    public let baseURL: URL
    
    public init(anonKey: String, baseURL: URL) {
        self.anonKey = anonKey
        self.baseURL = baseURL
    }
}
