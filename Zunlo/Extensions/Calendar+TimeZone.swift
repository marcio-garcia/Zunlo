//
//  Calendar+TimeZone.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

extension Calendar {
    
    static var appDefault: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }
    
    static func utc() -> Calendar {
        var c = Calendar.appDefault
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
}
