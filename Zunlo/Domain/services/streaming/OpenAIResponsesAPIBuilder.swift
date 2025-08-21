//
//  OpenAIResponsesAPIBuilder.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/20/25.
//

import Foundation

public struct OpenAIResponsesAPIBuilder {
    
    /// Build the HTTP body for the OpenAI **Responses API** from a chat history.
    /// - Only the **last** message contributes attachments (as additional `input_text` parts containing JSON strings).
    /// - Earlier messages contribute text only.
    /// - Non-JSON attachments are ignored (extend as needed).
//    public static func buildResponsesHTTPBody(
//        from messages: [ChatMessage],
//        model: String = "gpt-4o-mini",
//        instructions: String? = nil,
//        temperature: Double? = 0.2,
//        defaultNonUserRole: String = "assistant",
//        includeEmptyTurns: Bool = false,
//        maxTurnsCount: Int = 8,
//        functionOutput: [ToolOutput]
//    ) throws -> ResponsesRequest {
//        guard !messages.isEmpty else {
//            return ResponsesRequest(model: model, instructions: instructions, input: [], temperature: temperature, metadata: nil)
//        }
//
//        var turns: [InputContent] = []
//        var firstSchemaFromLast: String?
//
//        for (idx, msg) in messages.enumerated() {
//            var parts: [String] = []
//
//            if !msg.text.isEmpty {
//                parts.append("[\(msg.text)]")
//            }
//
//            // Only include attachments for the last message
//            if idx == messages.count - 1 {
//                for att in msg.attachments where att.mime == "application/json" {
//                    guard let data = Data(base64Encoded: att.dataBase64) else { continue }
//                    let jsonString = prettifyJSON(data) ?? String(data: data, encoding: .utf8) ?? "{}"
//                    parts.append("[\(jsonString)]")
//                    if firstSchemaFromLast == nil { firstSchemaFromLast = att.schema }
//                }
//            }
//
//            if parts.isEmpty, !includeEmptyTurns { continue }
//            let contentString = parts.joined(separator: "-")
//            if case .tool = msg.role, let output = functionOutput.first {
//                turns.append(InputFunctionCallOutput(
//                    type: "function_call_output",
//                    call_id: output.tool_call_id,
//                    output: output.output)
//                )
//            }
//            let role = mapRole(msg.role, defaultNonUser: defaultNonUserRole)
//            turns.append(InputContent(role: role, content: contentString))
//        }
//
//        let tail = Array(turns.suffix(maxTurnsCount))
//        
//        let body = ResponsesRequest(
//            model: model,
//            instructions: instructions,
//            input: tail,
//            temperature: temperature,
//            metadata: {
//                var m: [String: String] = ["app": "Zunlo"]
//                if let s = firstSchemaFromLast { m["payload_schema"] = s }
//                return m
//            }()
//        )
//
//        return body
//    }
    
    /// Build the HTTP body for the OpenAI **Responses API** from a chat history.
    /// - Only the **last** message contributes attachments (as additional `input_text` parts containing JSON strings).
    /// - Earlier messages contribute text only.
    /// - Non-JSON attachments are ignored (extend as needed).
    public static func buildResponsesHTTPBodyParts(
        from messages: [ChatMessage],
        model: String = "gpt-4o-mini",
        instructions: String? = nil,
        temperature: Double? = 0.2,
        defaultNonUserRole: String = "assistant",
        includeEmptyTurns: Bool = false,
        maxTurnsCount: Int = 8
    ) throws -> ResponsesRequestParts {
        guard !messages.isEmpty else {
            return ResponsesRequestParts(model: model, instructions: instructions, input: [], temperature: temperature, metadata: nil)
        }

        var turns: [InputTurn] = []
        var firstSchemaFromLast: String?

        for (idx, msg) in messages.enumerated() {
            var parts: [ContentPart] = []

            if !msg.rawText.isEmpty {
                parts.append(.inputText(msg.rawText))
            }

            // Only include attachments for the last message
            if idx == messages.count - 1 {
                for att in msg.attachments where att.mime == "application/json" {
                    guard let data = Data(base64Encoded: att.dataBase64) else { continue }
                    let jsonString = prettifyJSON(data) ?? String(data: data, encoding: .utf8) ?? "{}"
                    parts.append(.inputText(jsonString))
                    if firstSchemaFromLast == nil { firstSchemaFromLast = att.schema }
                }
            }

            if parts.isEmpty, !includeEmptyTurns { continue }
            let role = mapRole(msg.role, defaultNonUser: defaultNonUserRole)
            turns.append(InputTurn(role: role, content: parts))
        }

        let tail = Array(turns.suffix(maxTurnsCount))
        
        let body = ResponsesRequestParts(
            model: model,
            instructions: instructions,
            input: tail,
            temperature: temperature,
            metadata: {
                var m: [String: String] = ["app": "Zunlo"]
                if let s = firstSchemaFromLast { m["payload_schema"] = s }
                return m
            }()
        )

        return body
    }
    
    // MARK: - Role mapping (Responses API doesn't need "system"; prefer instructions)
    private static func mapRole(_ role: ChatRole, defaultNonUser: String) -> String {
        switch role {
        case .user: return "user"
        case .assistant, .tool: return defaultNonUser // treat tool output as assistant-side context
        case .system: return ""
        }
    }
    
    // Pretty-print JSON if possible; else return original string
    private static func prettifyJSON(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []),
              JSONSerialization.isValidJSONObject(obj),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) else {
            return String(data: data, encoding: .utf8)
        }
        return String(data: pretty, encoding: .utf8)
    }
}

// MARK: - Responses API payload models
public struct ResponsesRequestParts: Encodable {
    let model: String
    let instructions: String?
    let input: [InputTurn]
    let temperature: Double?
    let metadata: [String: String]?
}

public struct InputTurn: Encodable {
    let role: String           // "user" | "assistant"
    let content: [ContentPart] // text + (for last message) input_json
}

public struct InputContent: Encodable {
    public init(type: String? = nil, role: String? = nil, content: String? = nil, call_id: String? = nil, output: String? = nil) {
        self.type = type
        self.role = role
        self.content = content
        self.call_id = call_id
        self.output = output
    }
    
    let type: String?
    let role: String?           // "user" | "assistant"
    let content: String?  // text + (for last message) input_json
    let call_id: String?
    let output: String?
}

public struct InputFunctionCallOutput: Encodable {
    let type: String
    let call_id: String
    let output: String
}

public enum ContentPart: Encodable {
    case inputText(String)

    public func encode(to enc: Encoder) throws {
        var c = enc.container(keyedBy: CodingKeys.self)
        switch self {
        case .inputText(let t):
            try c.encode("input_text", forKey: .type)
            try c.encode(t, forKey: .text)
        }
    }
    enum CodingKeys: String, CodingKey { case type, text }
}

// MARK: - Tiny JSON re-encoder for input_json parts
public enum JSONValue: Encodable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(any: Any) {
        switch any {
        case let d as [String: Any]: self = .object(d.mapValues { JSONValue(any: $0) })
        case let a as [Any]:         self = .array(a.map { JSONValue(any: $0) })
        case let s as String:        self = .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { self = .bool(n.boolValue) }
            else { self = .number(n.doubleValue) }
        default:                     self = .null
        }
    }
}
