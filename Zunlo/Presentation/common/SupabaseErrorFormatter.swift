//
//  SupabaseErrorFormatter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import Foundation
import SupabaseSDK

enum SupabaseErrorFormatter {
    static func format(_ error: Error) -> String {
        switch error {
        case let databaseError as SupabaseServiceError:
            return formatSupabaseServiceError(databaseError)
        default:
            return error.localizedDescription
        }
    }

    private static func formatSupabaseServiceError(_ error: SupabaseServiceError) -> String {
        switch error {
        case .serverError(statusCode: let statusCode, _, supabaseError: let supabaseError):
            guard let supabaseError else {
                return "status code: \(statusCode) - \(error.localizedDescription)"
            }
            
            guard supabaseError.message != "Unauthorized" else {
                NotificationCenter.default.post(name: Notification.Name.accessUnauthorized, object: nil)
                return ""
            }
            
            let description = [
                supabaseError.message,
                supabaseError.details,
                supabaseError.hint
            ].compactMap { $0 }.joined(separator: " - ")
            return "status code: \(statusCode) - \(supabaseError.code) - \(description)"

        case .decodingError(let err):
            if let decodingErr = err as? DecodingError {
                return formatDecodingError(decodingErr)
            } else {
                return "Unknown decoding error: \(err.localizedDescription)"
            }

        case .encodingError(let err):
            if let encodingErr = err as? EncodingError {
                return formatEncodingError(encodingErr)
            } else {
                return "Unknown encoding error: \(err.localizedDescription)"
            }

        case .networkError(let err):
            return err.localizedDescription
        }
    }


    private static func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Decoding error: type mismatch for \(type) at \(context.codingPath) – \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Decoding error: value not found for \(type) at \(context.codingPath) – \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Decoding error: key '\(key.stringValue)' not found – \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Decoding error: data corrupted – \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }

    private static func formatEncodingError(_ error: EncodingError) -> String {
        switch error {
        case .invalidValue(let value, let context):
            return "Encoding error: invalid value \(value) at \(context.codingPath) – \(context.debugDescription)"
        @unknown default:
            return "Unknown encoding error"
        }
    }
}
