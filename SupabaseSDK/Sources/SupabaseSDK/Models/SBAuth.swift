//
//  SBAuth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public struct SBAuth: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let expiresAt: Date
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.tokenType = try container.decode(String.self, forKey: .tokenType)
        self.expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.user = try container.decode(SBUser.self, forKey: .user)
        
        // Decode Unix timestamp as Double or Int, then convert to Date
        let timestamp = try container.decode(Double.self, forKey: .expiresAt)
        self.expiresAt = Date(timeIntervalSince1970: timestamp)
        
//        // Decode ISO 8601 string
//        let createdAtString = try container.decode(String.self, forKey: .createdAt)
//        let isoFormatter = ISO8601DateFormatter()
//        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//        guard let createdDate = isoFormatter.date(from: createdAtString) else {
//            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid ISO8601 date format")
//        }
//        self.createdAt = createdDate
    }
}
