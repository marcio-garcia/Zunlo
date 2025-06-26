//
//  DateExt.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

extension Date {
    
    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    static let isoFormatter = ISO8601DateFormatter()
    
    func formattedDate(dateFormat: String) -> String {
        Date.formatter.dateFormat = dateFormat
        return Date.formatter.string(from: self)
    }
}
