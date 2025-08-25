//
//  NSRegularExpression+Match.swift
//  ZunloHelpers
//
//  Created by Marcio Garcia on 8/24/25.
//

import Foundation

public extension NSRegularExpression {
    func matches(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return firstMatch(in: s, options: [], range: range) != nil
    }
}
