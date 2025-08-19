//
//  SSEParser.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

/// A simple, tolerant SSE parser.
/// - Keeps an internal buffer across chunks
/// - Splits packets on both `\n\n` and `\r\n\r\n`
/// - Supports multiple `data:` lines per event (concatenated)
/// - Ignores comments/keep-alives (`:`) and empty lines
public struct SSEEvent {
    public let event: String?   // e.g. "response.output_text.delta"
    public let data: String     // payload for that event (usually JSON or text)
}

public struct SSEParser {
    private var buffer = Data()

    public init() {}

    /// Feed raw bytes and receive zero or more parsed SSE events.
    public mutating func feed(_ chunk: Data) -> [SSEEvent] {
        buffer.append(chunk)
        var out: [SSEEvent] = []

        // Split on either LF-LF or CRLF-CRLF
        let sep1 = Data("\n\n".utf8)
        let sep2 = Data("\r\n\r\n".utf8)

        while true {
            let range = buffer.range(of: sep1) ?? buffer.range(of: sep2)
            guard let packetRange = range else { break }

            let packet = buffer.subdata(in: 0..<packetRange.lowerBound)
            buffer.removeSubrange(0..<packetRange.upperBound)

            guard let s = String(data: packet, encoding: .utf8) else { continue }
            if let ev = Self.parsePacket(s) { out.append(ev) }
        }

        return out
    }

    /// Parse a single SSE packet (no trailing \n\n)
    private static func parsePacket(_ packet: String) -> SSEEvent? {
        var name: String?
        var dataLines: [String] = []

        for rawLine in packet.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix(":") { continue } // comment/keep-alive

            if line.hasPrefix("event:") {
                name = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else {
                // Some servers may omit the "data:" prefix; treat as data
                dataLines.append(line)
            }
        }

        let data = dataLines.joined()
        guard !data.isEmpty else { return nil }
        return SSEEvent(event: name, data: data)
    }
}
