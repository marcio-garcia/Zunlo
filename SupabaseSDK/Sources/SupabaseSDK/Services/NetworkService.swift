//
//  NetworkService.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 7/19/25.
//

import Foundation

class NetworkService {
    
    struct EmptyRequest: Encodable {}
    struct EmptyResponse: Decodable {}
    
    private let httpClient: NetworkClient
    
    init(config: SupabaseConfig, session: URLSession) {
        self.httpClient = NetworkClient(baseURL: config.baseURL,
                                        apiKey: config.anonKey,
                                        session: session)
    }
    
    var authToken: String? {
        didSet {
            httpClient.authToken = authToken
        }
    }

    func perform<RequestBody: Encodable, ResponseBody: Decodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        bodyObject: RequestBody? = nil,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> ResponseBody {
        do {
            let (data, response) = try await perform(
                baseURL: baseURL,
                path: path,
                method: method,
                bodyObject: bodyObject,
                query: query,
                additionalHeaders: additionalHeaders
            )
            
            try throwIfNotSuccessStatus(response.statusCode, data: data, decoder: JSONDecoder())
            
            return try decode(data)
            
        } catch let decodingError as DecodingError {
            throw SupabaseServiceError.decodingError(decodingError)
        } catch let encodingError as EncodingError {
            throw SupabaseServiceError.encodingError(encodingError)
        } catch let knownError as SupabaseServiceError {
            throw knownError
        } catch {
            throw SupabaseServiceError.networkError(error)
        }
    }
    
    func perform<RequestBody: Encodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        bodyObject: RequestBody? = nil,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let body = bodyObject == nil ? nil : try encode(bodyObject!)
        let headers = buildHeaders(additionalHeaders)
        
        let (data, response) = try await httpClient.sendRequest(
            baseURL: baseURL,
            path: path,
            method: method,
            query: query,
            body: body,
            additionalHeaders: headers
        )
        
        return (data, response)
    }
    
    func performRequest<ResponseBody: Decodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> ResponseBody {
        return try await perform(
            baseURL: baseURL,
            path: path,
            method: method,
            bodyObject: .none as EmptyRequest?,
            query: query,
            additionalHeaders: additionalHeaders
        )
    }

    func performRequest<RequestBody: Encodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        bodyObject: RequestBody,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> Void {
        _ = try await perform(
            baseURL: baseURL,
            path: path,
            method: method,
            bodyObject: bodyObject,
            query: query,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }
    
    func performRequest(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> Void {
        let (data, response) = try await perform(
            baseURL: baseURL,
            path: path,
            method: method,
            bodyObject: .none as EmptyRequest?,
            query: query,
            additionalHeaders: additionalHeaders
        )
        
        try throwIfNotSuccessStatus(response.statusCode, data: data, decoder: JSONDecoder())
    }

    private func buildHeaders(_ additional: [String: String]?) -> [String: String] {
        var headers = additional ?? [:]
        headers["Content-Type"] = "application/json"
        return headers
    }
    
    private func throwIfNotSuccessStatus(
        _ statusCode: Int,
        data: Data,
        decoder: JSONDecoder = .init()
    ) throws {
        guard 200..<300 ~= statusCode else {
            // Attempt fallback decoding into multiple error types
            let error = decodeFirstMatchingErrorType(
                data,
                using: decoder,
                from: [
                    SupabaseAuthErrorResponse.self,
                    SupabaseStorageErrorResponse.self,
                    SupabaseUnauthorizedErrorResponse.self
                ],
                statusCode: statusCode
            )
            throw error
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

    /// Tries decoding `data` into the first matching type in the given list of `Decodable` types.
    private func decodeFirstMatchingErrorType(
        _ data: Data,
        using decoder: JSONDecoder = .init(),
        from types: [SupabaseErrorType.Type],
        statusCode: Int
    ) -> Error {
        var errors: [Error] = []
        var result: SupabaseErrorType?
        for type in types {
            do {
                result = try decoder.decode(type, from: data)
            } catch {
                errors.append(error)
            }
        }
        if let result {
            return SupabaseServiceError.serverError(statusCode: statusCode, body: data, supabaseError: result)
        } else {
            return errors.first!
        }
    }
}
