//
//  TitleExtractor.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/9/25.
//

import Foundation

public struct TitleExtractor {
    public init() {}

    /// Extracts the "title" portion of an input by stripping date/time spans.
    /// - Parameters:
    ///   - text: Full user input.
    ///   - ranges: Array of ranges of command or connector substrings.
    /// - Returns: Title candidate(s).
    public func extractTitle(from text: String, ranges: [Range<String.Index>], pack: DateLanguagePack) -> String {
        // 1) Collect match ranges and merge overlaps / duplicates
        let merged = mergeRanges(ranges, in: text)

        // 2) Build result by keeping everything outside merged ranges
        var pieces: [Substring] = []
        var cursor = text.startIndex
        for r in merged {
            if cursor < r.lowerBound {
                pieces.append(text[cursor..<r.lowerBound])
            }
            if cursor < r.upperBound {
                cursor = r.upperBound
            }
        }
        if cursor < text.endIndex {
            pieces.append(text[cursor..<text.endIndex])
        }
        var result = pieces.reduce(into: String(), { $0.append(contentsOf: $1) })

        // 3) Strip language-specific connector tokens
        let tokens = pack.connectorTokens
        for tok in tokens {
            result = result.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: tok))\\b",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // 4) Strip command prefixes, only at the beginning
        let regexList = pack.commandPrefixRegex()
        for rx in regexList {
            while let m = rx.firstMatch(in: result, options: [], range: NSRange(result.startIndex..., in: result)),
                  m.range.location == 0, m.range.length > 0,
                  let r = Range(m.range, in: result) {
                result.removeSubrange(r)
            }
        }

        // 5) Normalize whitespace & stray punctuation
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^[\s,;:.-]+"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[\s,;:.-]+$"#, with: "", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Merge/union an array of string-index ranges (assumes all ranges belong to `text`).
    /// Overlapping or identical ranges are coalesced; output is sorted and non-overlapping.
    private func mergeRanges(_ ranges: [Range<String.Index>], in text: String) -> [Range<String.Index>] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }

        var merged: [Range<String.Index>] = []
        var current = sorted[0]

        for r in sorted.dropFirst() {
            if r.lowerBound <= current.upperBound { // overlap or adjacency
                // extend current to cover r as well
                if r.upperBound > current.upperBound {
                    current = current.lowerBound..<r.upperBound
                }
            } else {
                merged.append(current)
                current = r
            }
        }
        merged.append(current)
        return merged
    }
}
