//
//  String+Date.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation

extension String {
    func toDate(format: String) -> Date? {
        Date.formatter.dateFormat = format
        return Date.formatter.date(from: self)
    }
}
