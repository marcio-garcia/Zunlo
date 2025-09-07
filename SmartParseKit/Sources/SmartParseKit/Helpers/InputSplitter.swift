//
//  InputSplitter.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/6/25.
//

import Foundation
import NaturalLanguage

public struct SplitClause: Equatable {
    public let text: String
    public let range: Range<String.Index>
}

/// Splits multi-intent inputs into simpler command-like clauses.
/// Strategy:
/// 1) Sentence split (NLTokenizer)
/// 2) Within each sentence, split by “command connectors” (EN + pt-BR)
/// 3) Avoid splitting inside quotes/parentheses
/// 4) Merge short polite tails (e.g., “please”, “por favor”)
public struct InputSplitter {

    public init() {}

    // Connectors that often indicate a new action (ordered by strength)
    private let strongConnectors: [String] = [
        // English
        "and then", ", then", "then", "also", ";", "—",
        // pt-BR
        "e depois", ", depois", "depois", "também", ";"
    ]

    // Polite tails we prefer to merge back
    private let politeEN = ["please"]
    private let politePT = ["por favor"]

    @discardableResult
    public func split(_ raw: String, language: NLLanguage?) -> [SplitClause] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // 1) Sentence split
        let sentTok = NLTokenizer(unit: .sentence)
        sentTok.string = text
        var sentenceRanges: [Range<String.Index>] = []
        sentTok.enumerateTokens(in: text.startIndex..<text.endIndex) { r, _ in
            sentenceRanges.append(r)
            return true
        }
        if sentenceRanges.isEmpty { sentenceRanges = [text.startIndex..<text.endIndex] }

        // 2) Split by connectors inside each sentence
        var ranges: [Range<String.Index>] = []
        for r in sentenceRanges {
            ranges.append(contentsOf: splitByConnectors(in: text, range: r))
        }

        // 3) Trim empties
        var clauses: [SplitClause] = ranges.compactMap { r in
            let s = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : SplitClause(text: s, range: r)
        }

        // 4) Merge polite tails
        clauses = mergeHangingTails(clauses: clauses, in: text, language: language)

        return clauses
    }

    // MARK: - Internals

    private func splitByConnectors(in text: String, range: Range<String.Index>) -> [Range<String.Index>] {
        let sliceStr = String(text[range]) // local buffer for safe indexing

        // 1) Connector regex (EN + pt-BR)
        let connectorAlts = [
            // English
            "and then", "then", "and", "also",
            // pt-BR
            "e depois", "depois", "e", "também"
        ]
        let pattern = #"\b(?:\#(connectorAlts.map(NSRegularExpression.escapedPattern).joined(separator: "|")))\b"#
        let re = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        // 2) Protected spans (quotes / parentheses) in local coordinates
        let protected = protectedSpans(in: sliceStr)
        @inline(__always) func isProtected(_ offset: Int) -> Bool {
            for pr in protected { if pr.contains(offset) { return true } }
            return false
        }

        // 3) Find all connector matches and expand left/right to absorb light delimiters
        var removalRanges: [Range<Int>] = []
        let fullNS = NSRange(location: 0, length: (sliceStr as NSString).length)

        re.enumerateMatches(in: sliceStr, options: [], range: fullNS) { m, _, _ in
            guard let m = m else { return }
            let start = m.range.lowerBound
            guard !isProtected(start) else { return }

            var left = start
            while left > 0, isLightDelimiter(sliceStr.char(at: left - 1)) {
                left -= 1
            }
            var right = m.range.upperBound
            while right < sliceStr.count, isLightDelimiter(sliceStr.char(at: right)) {
                right += 1
            }
            if left < right { removalRanges.append(left..<right) }
        }

        // 4) Merge overlapping removal ranges
        removalRanges.sort { $0.lowerBound < $1.lowerBound }
        var merged: [Range<Int>] = []
        for r in removalRanges {
            if let last = merged.last, last.overlaps(r) || last.upperBound == r.lowerBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, r.upperBound)
            } else {
                merged.append(r)
            }
        }

        // 5) Build kept segments by cutting out removal ranges
        var kept: [Range<Int>] = []
        var cursor = 0
        for cut in merged {
            if cursor < cut.lowerBound {
                if let seg = trimDelimiters(in: sliceStr, local: cursor..<cut.lowerBound) {
                    kept.append(seg)
                }
            }
            cursor = cut.upperBound
        }
        if cursor < sliceStr.count {
            if let seg = trimDelimiters(in: sliceStr, local: cursor..<sliceStr.count) {
                kept.append(seg)
            }
        }

        // 6) Map local kept ranges back to global `text` indices
        let out: [Range<String.Index>] = kept.compactMap { local in
            guard local.lowerBound < local.upperBound else { return nil }
            let start = text.index(range.lowerBound, offsetBy: local.lowerBound)
            let end = text.index(range.lowerBound, offsetBy: local.upperBound)
            return start..<end
        }

        return out.isEmpty ? [range] : out
    }
    
    // MARK: - Delimiter logic

    /// Delimiters we are willing to swallow/trim around connectors.
    /// IMPORTANT: do NOT include quotes/brackets/parens here, so we don't eat closing " or ) from the left clause.
    @inline(__always)
    private func isLightDelimiter(_ ch: Character) -> Bool {
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" { return true }
        switch ch {
        case ",", ";", ":", "-", "–", "—":
            return true
        default:
            return false
        }
    }

    /// Helper to drop junk-only slices (e.g., ", ", ";  ").
    @inline(__always)
    private func isDelimiterOnly(_ s: String) -> Bool {
        let set = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–—"))
        return s.unicodeScalars.allSatisfy { set.contains($0) }
    }

    /// Trim ONLY light delimiters at both ends of a local range in `s`.
    /// Returns nil if the range becomes empty or contains only delimiters.
    private func trimDelimiters(in s: String, local: Range<Int>) -> Range<Int>? {
        guard local.lowerBound < local.upperBound else { return nil }
        let chars = Array(s)
        var a = local.lowerBound
        var b = local.upperBound

        while a < b, isLightDelimiter(chars[a]) { a += 1 }
        while b > a, isLightDelimiter(chars[b - 1]) { b -= 1 }

        return (a < b) ? (a..<b) : nil
    }

    // MARK: - Protected spans (quotes / parentheses)

    /// Returns local ranges within `s` that are inside quotes or parentheses and should not be split/trimmed through.
    private func protectedSpans(in s: String) -> [Range<Int>] {
        var spans: [Range<Int>] = []
        var quoteStart: Int? = nil
        var parenStack: [Int] = []
        let chars = Array(s)

        func closeQuote(_ i: Int) {
            if let q = quoteStart {
                spans.append(q..<(i + 1))
                quoteStart = nil
            }
        }

        for (i, ch) in chars.enumerated() {
            switch ch {
            case "\"","“","”","«","»","‘","’","'":
                if quoteStart == nil {
                    quoteStart = i
                } else {
                    closeQuote(i)
                }
            case "(":
                parenStack.append(i)
            case ")":
                if let open = parenStack.popLast() {
                    spans.append(open..<(i + 1))
                }
            default:
                continue
            }
        }
        return spans
    }

    /// Merge tiny non-command tails into the previous clause (e.g., "please", "por favor", "also", "também").
    private func mergeHangingTails(clauses: [SplitClause], in text: String, language: NLLanguage?) -> [SplitClause] {
        guard clauses.count > 1 else { return clauses }

        let isPT = language?.rawValue.lowercased().hasPrefix("pt") == true
        let polite = isPT ? politePT : politeEN
        let fillers = polite + (isPT ? ["também"] : ["also"])

        var out: [SplitClause] = []
        var i = 0
        while i < clauses.count {
            if i < clauses.count - 1 {
                let next = clauses[i + 1].text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if fillers.contains(next) {
                    // merge
                    let a = clauses[i]
                    let b = clauses[i + 1]
                    let mergedText = a.text + " " + b.text
                    let mergedRange = a.range.lowerBound..<b.range.upperBound
                    out.append(SplitClause(text: mergedText, range: mergedRange))
                    i += 2
                    continue
                }
            }
            out.append(clauses[i])
            i += 1
        }
        return out
    }
}

// Convenience to read by character index from a String treated as array
private extension String {
    func char(at i: Int) -> Character {
        self[index(startIndex, offsetBy: i)]
    }
}
