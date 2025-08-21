//
//  FnCallAccumulator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

struct Call {
    var id: String
    var name: String
    var callId: String
    var args: String
}

struct FnCallAccumulator {
    var responseId: String?
    var calls: [String: Call] = [:] // key by output item id / call id

    mutating func startCall(id: String, name: String, callId: String) {
        calls[id] = Call(id: id, name: name, callId: callId, args: "")
    }
    mutating func appendArgs(id: String, chunk: String) {
        calls[id]?.args.append(chunk)
    }
    mutating func finishCall(id: String, args: String) -> Call? {
        guard var c = calls.removeValue(forKey: id) else { return nil }
        // Some models stream raw JSON fragments; ensure it’s valid JSON string
//        c.args += args
        c.args = c.args.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.args.isEmpty { c.args = "{}" }
        return c
    }
}
