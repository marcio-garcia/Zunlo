//
//  SBAuth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

public struct SBAuth: Codable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let expiresAt: Int
    public let refreshToken: String
    public let user: SBUser
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case refreshToken = "refresh_token"
        case user
    }
}
