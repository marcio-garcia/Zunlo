//
//  MarkdownFormatDetector.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/24/25.
//

import Foundation

private enum MD {
    static let headings = try! NSRegularExpression(pattern: #"(?m)^#{1,6}\s"#)
    static let bullets  = try! NSRegularExpression(pattern: #"(?m)^(?:-|\*|\+|\d+\.)\s"#)
    static let link     = try! NSRegularExpression(pattern: #"\[[^\]]+\]\([^)]+\)"#)
    static let tableHdr = try! NSRegularExpression(pattern: #"(?m)^\|.+\|\s*\n\|[-:| ]+\|"#)
}

extension String {
    func matches(_ re: NSRegularExpression) -> Bool {
        re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
}

class MarkdownFormatDetector {
    private(set) var decided = false
    private var score = 0
    private var tail = ""
    private let threshold = 2

    func feed(_ chunk: String) -> Bool {
        guard !decided else { return true }
        let window = tail + chunk

        if window.contains("```") { score += 2 }
        if window.contains("`")   { score += 1 }
        if window.matches(MD.headings) { score += 1 }
        if window.matches(MD.bullets)  { score += 1 }
        if window.matches(MD.link)     { score += 1 }
        if window.contains("**") || window.contains("__") { score += 1 }
        if window.matches(MD.tableHdr) { score += 1 }

        decided = score >= threshold
        tail = String(window.suffix(128))
        return decided
    }
}
