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
    
//    func performRequest<T: Codable>(
//        baseURL: URL? = nil,
//        path: String,
//        method: HTTPMethod,
//        bodyObject: T? = nil,
//        query: [String: String]? = nil,
//        additionalHeaders: [String: String]? = nil
//    ) async throws -> [T] {
//        do {
//            let body = bodyObject == nil ? nil : try encode(bodyObject!)
//            let headers = buildHeaders(additionalHeaders)
//            
//            let (data, response) = try await httpClient.sendRequest(
//                baseURL: baseURL,
//                path: path,
//                method: method,
//                query: query,
//                body: body,
//                additionalHeaders: headers
//            )
//            
//            try throwIfNotSuccessStatus(response.statusCode, data: data, decoder: JSONDecoder())
//            
//            return try decode(data)
//            
//        } catch let decodingError as DecodingError {
//            throw SupabaseServiceError.decodingError(decodingError)
//        } catch let encodingError as EncodingError {
//            throw SupabaseServiceError.encodingError(encodingError)
//        } catch let knownError as SupabaseServiceError {
//            throw knownError
//        } catch {
//            throw SupabaseServiceError.networkError(error)
//        }
//    }

    func performRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        bodyObject: RequestBody? = nil,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> ResponseBody {
        do {
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
    
    func performRequest<ResponseBody: Decodable>(
        baseURL: URL? = nil,
        path: String,
        method: HTTPMethod,
        query: [String: String]? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> ResponseBody {
        try await performRequest<EmptyRequest, ResponseBody>(
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
        _ = try await performRequest<RequestBody, EmptyResponse>(
            baseURL: baseURL,
            path: path,
            method: method,
            bodyObject: bodyObject,
            query: query,
            additionalHeaders: additionalHeaders
        )
    }

    private func buildHeaders(_ additional: [String: String]?) -> [String: String] {
        var headers = additional ?? [:]
        headers["Content-Type"] = "application/json"
        return headers
    }

//    private func throwIfNotSuccessStatus(
//        _ statusCode: Int,
//        data: Data,
//        decoder: JSONDecoder = .init()
//    ) throws {
//        guard 200..<300 ~= statusCode else {
//            do {
//                let decodedError = try decoder.decode(SupabaseErrorResponse.self, from: data)
//                throw SupabaseServiceError.serverError(
//                    statusCode: statusCode,
//                    body: data,
//                    supabaseError: decodedError
//                )
//            } catch let knownError as SupabaseServiceError {
//                throw knownError
//            } catch {
//                throw SupabaseServiceError.decodingError(error)
//            }
//        }
//    }
    
    private func throwIfNotSuccessStatus(
        _ statusCode: Int,
        data: Data,
        decoder: JSONDecoder = .init()
    ) throws {
        guard 200..<300 ~= statusCode else {
            // Attempt fallback decoding into multiple error types
            if let supabaseError = decodeFirstMatchingErrorType(
                data,
                using: decoder,
                from: [
                    SupabaseAuthErrorResponse.self,
                    SupabaseStorageErrorResponse.self
                ]
            ) {
                throw SupabaseServiceError.serverError(
                    statusCode: statusCode,
                    body: data,
                    supabaseError: supabaseError
                )
            } else {
                throw SupabaseServiceError.decodingError(
                    DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown error format"))
                )
            }
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
        from types: [SupabaseErrorType.Type]
    ) -> SupabaseErrorType? {
        for type in types {
            if let decoded = try? decoder.decode(type, from: data) {
                return decoded
            }
        }
        return nil
    }
//    private func decodeFirstMatchingErrorType<T: Decodable>(
//        _ data: Data,
//        using decoder: JSONDecoder = .init(),
//        from types: [T.Type]
//    ) -> T? {
//        for type in types {
//            if let decoded = try? decoder.decode(type, from: data) {
//                return decoded
//            }
//        }
//        return nil
//    }
}
