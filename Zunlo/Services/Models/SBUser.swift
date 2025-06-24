//
//  SBUser.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

//struct SBUser: Codable {
//    let id: String    // The unique id of the identity of the user.
//    let aud: String    // The audience claim.
//    let role: String    // The role claim used by Postgres to perform Row Level Security (RLS) checks.
//    let email: String    // The user's email address.
//    let emailConfirmedAt: String?    // The timestamp that the user's email was confirmed. If null, it means that the user's email is not confirmed.
//    let phone: String    // The user's phone number.
//    let phoneConfirmedAt: String?    // The timestamp that the user's phone was confirmed. If null, it means that the user's phone is not confirmed.
//    let confirmationSentAt: String?
//    let confirmedAt: String    // The timestamp that either the user's email or phone was confirmed. If null, it means that the user does not have a confirmed email address and phone number.
//    let lastSignInAt: String    // The timestamp that the user last signed in.
//    let appMetadata: SBAppMetadata    // The provider attribute indicates the first provider that the user used to sign up with. The providers attribute indicates the list of providers that the user can use to login with.
//    let userMetadata: SBMetadata    // Defaults to the first provider's identity data but can contain additional custom user metadata if specified. Refer to User Identity for more information about the identity object.
//    let identities: [SBIdentities]    // Contains an object array of identities linked to the user.
//    let createdAt: String    // The timestamp that the user was created.
//    let updatedAt: String    // The timestamp that the user was last updated.
//    let isAnonymous: Bool
//    
//    private enum CodingKeys: String, CodingKey {
//        case id
//        case aud
//        case role
//        case email
//        case emailConfirmedAt = "email_confirmed_at"
//        case phone
//        case phoneConfirmedAt = "phone_confirmed_at"
//        case confirmationSentAt = "confirmation_sent_at"
//        case confirmedAt = "confirmed_at"
//        case lastSignInAt = "last_sign_in_at"
//        case appMetadata = "app_metadata"
//        case userMetadata = "user_metadata"
//        case identities
//        case createdAt = "created_at"
//        case updatedAt = "updated_at"
//        case isAnonymous = "is_anonymous"
//    }
//}
