//
//  FnCallAccumulator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

struct FnCallAccumulator {
    struct Call { var name: String; var args: String }
    var responseId: String?
    var calls: [String: Call] = [:] // key by output item id / call id

    mutating func startCall(id: String, name: String) {
        calls[id] = Call(name: name, args: "")
    }
    mutating func appendArgs(id: String, chunk: String) {
        calls[id]?.args.append(chunk)
    }
    mutating func finishCall(id: String) -> (name: String, argsJSON: String)? {
        guard let c = calls.removeValue(forKey: id) else { return nil }
        // Some models stream raw JSON fragments; ensure it’s valid JSON string
        let json = c.args.trimmingCharacters(in: .whitespacesAndNewlines)
        return (c.name, json.isEmpty ? "{}" : json)
    }
}
