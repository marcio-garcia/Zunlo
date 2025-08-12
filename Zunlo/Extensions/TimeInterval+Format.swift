//
//  TimeInterval+Format.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import Foundation

extension TimeInterval {
    func formatHM() -> String {
        let seconds = self
        let f = DateComponentsFormatter()
        f.unitsStyle = .short
        f.zeroFormattingBehavior = [.dropAll]
        if seconds >= 3600 {
            f.allowedUnits = [.hour, .minute]
            f.maximumUnitCount = 2
        } else {
            f.allowedUnits = [.minute]
        }
        return f.string(from: seconds) ?? "\(Int(seconds / 60)) min"
    }
}
