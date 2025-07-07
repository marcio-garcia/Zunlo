//
//  Calendar+Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/6/25.
//

import Foundation

extension Calendar {
    public static let event: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()
}
