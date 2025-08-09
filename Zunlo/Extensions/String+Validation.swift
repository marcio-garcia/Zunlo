//
//  String+Validation.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

extension String {
    var nilIfEmpty: String? {
        self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
