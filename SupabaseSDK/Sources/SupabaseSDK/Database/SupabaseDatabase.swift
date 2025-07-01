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
    private let httpClient: NetworkClient
    
    var authToken: String? {
        didSet {
            httpClient.authToken = authToken
        }
    }
    
    public init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.httpClient = NetworkClient(config: config, session: session)
    }
    
    public func fetch<T: Decodable>(from table: String,
                                    as type: T.Type = T.self,
                                    query: [String: String]? = nil) async throws -> [T] {
        let (data, response) = try await httpClient.sendRequest(
            path: "/rest/v1/\(table)",
            method: "GET",
            query: query
        )
        guard 200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
    
    public func insert<T: Codable>(_ object: T,
                                   into table: String) async throws -> [T] {
        let body = try encode(object)
        let (data, response) = try await httpClient.sendRequest(
            path: "/rest/v1/\(table)",
            method: "POST",
            body: body,
            additionalHeaders: ["Content-Type": "application/json"]
        )
        guard 200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
    
    public func update<T: Codable>(_ object: T,
                                   in table: String,
                                   filter: [String: String]) async throws -> [T] {
        let body = try encode(object)
        let (data, response) = try await httpClient.sendRequest(
            path: "/rest/v1/\(table)",
            method: "PATCH",
            query: filter,
            body: body,
            additionalHeaders: ["Content-Type": "application/json"]
        )
        guard 200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
    
    public func delete<T: Codable>(from table: String,
                                   filter: [String: String]) async throws -> [T] {
        let (data, response) = try await httpClient.sendRequest(
            path: "/rest/v1/\(table)",
            method: "DELETE",
            query: filter
        )
        guard 200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
    
    private func encode<T: Encodable>(_ object: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(object)
    }
    
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
