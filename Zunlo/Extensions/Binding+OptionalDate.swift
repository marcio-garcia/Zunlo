//
//  Binding+OptionalDate.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

extension Binding where Value == Date? {
    static func replacingNil(_ binding: Binding<Date?>, with fallback: Date) -> Binding<Date> {
        Binding<Date>(
            get: { binding.wrappedValue ?? fallback },
            set: { binding.wrappedValue = $0 }
        )
    }
}
