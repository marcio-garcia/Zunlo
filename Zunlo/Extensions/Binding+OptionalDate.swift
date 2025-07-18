//
//  Binding+OptionalDate.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

//extension Binding where Value == Date? {
//    static func replacingNil(_ binding: Binding<Date?>, with fallback: Date) -> Binding<Date> {
//        Binding<Date>(
//            get: { binding.wrappedValue ?? fallback },
//            set: { binding.wrappedValue = $0 }
//        )
//    }
//}

extension Binding where Value: ExpressibleByNilLiteral {
    func replacingNil<T>(with defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
//
//extension Binding {
//    static func replacingNil<T>(_ binding: Binding<T?>, with defaultValue: T) -> Binding<T> {
//        Binding<T>(
//            get: { binding.wrappedValue ?? defaultValue },
//            set: { binding.wrappedValue = $0 }
//        )
//    }
//}
