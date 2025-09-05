//
//  ResponsesApiTextRequest.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/5/25.
//

public struct ResponsesApiTextRequest: Encodable {
    let model: String
    let instructions: String?
    let previous_response_id: String?
    let input: [InputContent]
    let temperature: Double?
    let metadata: [String: String]?
    let localNowISO: String?
    let localTimezone: String?
    let response_type: ResponseType?
}

public enum ResponseType: String, Encodable {
    case plain
    case tools
    case structured
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
