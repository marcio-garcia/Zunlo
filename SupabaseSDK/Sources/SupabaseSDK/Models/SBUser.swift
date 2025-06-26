//
//  SBUser.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

public struct SBUser: Codable, Sendable {
    public let id: String    // The unique id of the identity of the user.
    public let aud: String    // The audience claim.
    public let role: String    // The role claim used by Postgres to perform Row Level Security (RLS) checks.
    public let email: String    // The user's email address.
    public let emailConfirmedAt: String?    // The timestamp that the user's email was confirmed. If null, it means that the user's email is not confirmed.
    public let phone: String    // The user's phone number.
    public let phoneConfirmedAt: String?    // The timestamp that the user's phone was confirmed. If null, it means that the user's phone is not confirmed.
    public let confirmationSentAt: String?
    public let confirmedAt: String    // The timestamp that either the user's email or phone was confirmed. If null, it means that the user does not have a confirmed email address and phone number.
    public let lastSignInAt: String    // The timestamp that the user last signed in.
    public let appMetadata: SBAppMetadata    // The provider attribute indicates the first provider that the user used to sign up with. The providers attribute indicates the list of providers that the user can use to login with.
    public let userMetadata: SBMetadata    // Defaults to the first provider's identity data but can contain additional custom user metadata if specified. Refer to User Identity for more information about the identity object.
    public let identities: [SBIdentities]    // Contains an object array of identities linked to the user.
    public let createdAt: String    // The timestamp that the user was created.
    public let updatedAt: String    // The timestamp that the user was last updated.
    public let isAnonymous: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case aud
        case role
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case phone
        case phoneConfirmedAt = "phone_confirmed_at"
        case confirmationSentAt = "confirmation_sent_at"
        case confirmedAt = "confirmed_at"
        case lastSignInAt = "last_sign_in_at"
        case appMetadata = "app_metadata"
        case userMetadata = "user_metadata"
        case identities
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isAnonymous = "is_anonymous"
    }
}
