//
//  SBMetadata.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

public struct SBMetadata: Codable, Sendable {
    public let email: String
    public let emailVerified: Bool
    public let phoneVerified: Bool
    public let sub: String
    
    private enum CodingKeys: String, CodingKey {
        case email
        case emailVerified = "email_verified"
        case phoneVerified = "phone_verified"
        case sub
    }
}
