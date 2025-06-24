//
//  SBIdentities.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

public struct SBIdentities: Codable {
    public let identityId: String
    public let id: String
    public let userId: String
    public let identityData: SBMetadata
    public let provider: String
    public let lastSignInAt: String
    public let createdAt: String
    public let updatedAt: String
    public let email: String
    
    private enum CodingKeys: String, CodingKey {
        case identityId = "identity_id"
        case id
        case userId = "user_id"
        case identityData = "identity_data"
        case provider
        case lastSignInAt = "last_sign_in_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case email
    }
}
