//
//  SBAuthError.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

public enum SBAuthError: Error {
    case authError(SBAuthErrorMsg)
    case invalidResponse
    case invalidRequest
}

public struct SBAuthErrorMsg: Error, Codable {
    public let code: Int
    public let errorCode: String
    public let msg: String
    
    private enum CodingKeys: String, CodingKey {
        case code
        case errorCode = "error_code"
        case msg
    }
}
