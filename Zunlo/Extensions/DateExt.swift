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
        return df
    }()
    
    func formatted(dateFormat: String) -> String {
        Date.formatter.dateFormat = dateFormat
        return Date.formatter.string(from: self)
    }
}
