//
//  DateDetecting.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/8/25.
//

import Foundation

public protocol DateDetecting {
    func enumerateMatches(in text: String, range: NSRange, _ body: (NSTextCheckingResult) -> Void)
}

final public class AppleDateDetector: DateDetecting {
    private let detector: NSDataDetector?
    public init?() {
        self.detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }
    public func enumerateMatches(in text: String, range: NSRange, _ body: (NSTextCheckingResult) -> Void) {
        detector?.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            if let r = result { body(r) }
        }
    }
}
