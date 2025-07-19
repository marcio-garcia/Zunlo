//
//  SBAuthError.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public enum SupabaseServiceError: Error {
    case serverError(statusCode: Int, body: Data?, supabaseError: SupabaseErrorType?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
}

public protocol SupabaseErrorType: Codable, Sendable {
    var code: String { get }
    var message: String { get }
    var details: String? { get }
    var hint: String? { get }
}

struct SupabaseAuthErrorResponse: SupabaseErrorType {
    public let code: String
    public let errorCode: String
    public let message: String
    public let details: String?
    public let hint: String?
    
    private enum CodingKeys: String, CodingKey {
        case code
        case errorCode = "error_code"
        case message = "msg"
        case details
        case hint
        
    }
}

struct SupabaseStorageErrorResponse: SupabaseErrorType {
    public let code: String
    public let details: String?
    public let hint: String?
    public let message: String
}
