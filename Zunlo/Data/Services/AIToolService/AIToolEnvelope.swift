//
//  AIToolEnvelope.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation

public struct AIToolEnvelope: Codable {
    public let name: String
    public let argsJSON: String
}
/// Model-facing tool envelope. Handles arguments as either a JSON object or a JSON string.
//public struct AIToolEnvelope: Codable {
//    public let name: String
//    public let arguments: JSONEitherObjectOrString
//
//    public struct JSONEitherObjectOrString: Codable {
//        public let rawJSON: String
//        public init(from decoder: Decoder) throws {
//            let container = try decoder.singleValueContainer()
//            if let s = try? container.decode(String.self) {
//                rawJSON = s
//            } else if let obj = try? container.decode([String: AnyCodable].self) {
//                let data = try JSONEncoder().encode(obj)
//                rawJSON = String(data: data, encoding: .utf8) ?? "{}"
//            } else {
//                rawJSON = "{}"
//            }
//        }
//    }
//}
//
///// Tiny AnyCodable for argument passthrough
//public struct AnyCodable: Codable {}
//public extension KeyedDecodingContainer {
//    func decode(_ type: [String: AnyCodable].Type, forKey key: K) throws -> [String: AnyCodable] { [:] }
//}
