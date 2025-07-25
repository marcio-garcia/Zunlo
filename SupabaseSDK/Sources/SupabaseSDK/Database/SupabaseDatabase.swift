//
//  SupabaseDatabase.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

public final class SupabaseDatabase: @unchecked Sendable {
    private let config: SupabaseConfig
    private let session: URLSession
    private let httpService: NetworkService
    
    public var authToken: String? {
        didSet {
            httpService.authToken = authToken
        }
    }
    
    public init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.httpService = NetworkService(config: config, session: session)
    }
    
    public func fetch<T: Codable>(
        from table: String,
        as type: T.Type = T.self,
        query: [String: String]? = nil
    ) async throws -> [T] {
        try await httpService.performRequest(
            path: "/rest/v1/\(table)",
            method: .get,
            query: query
        )
    }

    public func fetchOccurrences<T: Codable>(
        as type: T.Type = T.self
    ) async throws -> [T] {
        try await httpService.performRequest(
            baseURL: config.functionsBaseURL,
            path: "/get_user_events",
            method: .get
        )
    }
    
    public func insert<T: Codable>(
        _ object: T,
        into table: String,
        additionalHeaders: [String: String]? = nil
    ) async throws -> [T] {
        try await httpService.perform(
            path: "/rest/v1/\(table)",
            method: .post,
            bodyObject: object,
            additionalHeaders: additionalHeaders
        )
    }

    public func update<T: Codable>(
        _ object: T,
        in table: String,
        filter: [String: String]
    ) async throws -> [T] {
        try await httpService.perform(
            path: "/rest/v1/\(table)",
            method: .patch,
            bodyObject: object,
            query: filter
        )
    }
    
    public func delete<T: Codable>(
        from table: String,
        filter: [String: String]
    ) async throws -> [T] {
        try await httpService.performRequest(
            path: "/rest/v1/\(table)",
            method: .delete,
            query: filter
        )
    }
    
    
}
