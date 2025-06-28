//
//  KeyedDecodingContainer+Error.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/28/25.
//

extension KeyedDecodingContainer {
    func decodeSafely<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        do {
            return try self.decode(T.self, forKey: key)
        } catch let error {
            // Try to extract the raw value if possible
            let rawValue: Any?
            if let value = try? decodeIfPresent(RawJSON.self, forKey: key) {
                rawValue = value.value
            } else {
                rawValue = nil
            }

            let path = codingPath.map(\.stringValue).joined(separator: ".") + "." + key.stringValue
            throw DetailedDecodingError.decodingError(path: path, value: rawValue, underlying: error)
        }
    }
}
