//
//  SupabaseDatabase.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

public enum SupabaseServiceError: Error {
    case serverError(statusCode: Int, body: Data?, supabaseError: SupabaseErrorResponse?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
}

public struct SupabaseErrorResponse: Decodable, Error {
    public let code: String
    public let details: String
    public let hint: String?
    public let message: String
}

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
    
    public func fetch<T: Codable>(
        from table: String,
        as type: T.Type = T.self,
        query: [String: String]? = nil
    ) async throws -> [T] {
        try await performRequest(
            path: "/rest/v1/\(table)",
            method: "GET",
            query: query
        )
    }

    public func fetchOccurrences<T: Codable>(
        as type: T.Type = T.self
    ) async throws -> [T] {
        try await performRequest(
            path: "/get_user_events",
            method: "GET"
        )
    }
    
    public func insert<T: Codable>(
        _ object: T,
        into table: String,
        additionalHeaders: [String: String]? = nil
    ) async throws -> [T] {
        try await performRequest(
            path: "/rest/v1/\(table)",
            method: "POST",
            bodyObject: object,
            additionalHeaders: additionalHeaders
        )
    }

    public func update<T: Codable>(
        _ object: T,
        in table: String,
        filter: [String: String]
    ) async throws -> [T] {
        try await performRequest(
            path: "/rest/v1/\(table)",
            method: "PATCH",
            bodyObject: object,
            query: filter
        )
    }
    
    public func delete<T: Codable>(
        from table: String,
        filter: [String: String]
    ) async throws -> [T] {
        try await performRequest(
            path: "/rest/v1/\(table)",
            method: "DELETE",
            query: filter
        )
    }
    
    private func performRequest<T: Codable>(
        path: String,
        method: String,
        bodyObject: T? = nil,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> [T] {
        do {
            let body = try encode(bodyObject)
            let headers = additionalHeaders?.merging(["Content-Type": "application/json"]) { _, new in new } ?? ["Content-Type": "application/json"]
            
            let (data, response) = try await httpClient.sendRequest(
                path: path,
                method: method,
                query: query,
                body: body,
                additionalHeaders: headers
            )
            
            guard 200..<300 ~= response.statusCode else {
                let decodedError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data)
                throw SupabaseServiceError.serverError(statusCode: response.statusCode, body: data, supabaseError: decodedError)
            }
            
            return try decode(data)
            
        } catch let decodingError as DecodingError {
            throw SupabaseServiceError.decodingError(decodingError)
        } catch let encodingError as EncodingError {
            throw SupabaseServiceError.encodingError(encodingError)
        } catch {
            throw SupabaseServiceError.networkError(error)
        }
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
