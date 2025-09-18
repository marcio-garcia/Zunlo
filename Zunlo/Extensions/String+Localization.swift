//
//  String+Localization.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/18/25.
//

extension String {
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }
}
