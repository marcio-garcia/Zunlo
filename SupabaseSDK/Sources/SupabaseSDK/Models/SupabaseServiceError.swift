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

struct SupabaseStorageErrorResponse: SupabaseErrorType {
    public let code: String
    public let details: String?
    public let hint: String?
    public let message: String
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.errorCode = try container.decode(String.self, forKey: .errorCode)
        self.message = try container.decode(String.self, forKey: .message)
        
        let code = try container.decode(Int.self, forKey: .code)
        
        self.code = String(code)
        
        self.details = nil
        self.hint = nil
    }
}

struct SupabaseUnauthorizedErrorResponse: SupabaseErrorType {
    public let code: String
    public let details: String?
    public let hint: String?
    public let message: String
    
    private enum CodingKeys: String, CodingKey {
        case code
        case message = "error"
        case details
        case hint
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.message = try container.decode(String.self, forKey: .message)
        self.code = "0"
        self.details = nil
        self.hint = nil
    }
}
