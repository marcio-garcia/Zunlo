//
//  Utils.swift
//  LoggingKit
//
//  Created by Marcio Garcia on 9/5/25.
//

import Foundation

@inline(__always)
func formatTS(_ date: Date) -> String {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
        // Value-typed, Sendable formatting (no shared global formatter)
        return date.formatted(
            .iso8601
                .dateSeparator(.dash)
                .timeSeparator(.colon)
                .timeZoneSeparator(.colon)
                .time(includingFractionalSeconds: true)
        )
    } else {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
