//
//  Optional+Validation.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let s) where s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: return nil
        default: return self
        }
    }
}
