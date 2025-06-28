//
//  RawJSON.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/28/25.
//

struct RawJSON: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if container.decodeNil() {
            value = "null"
        } else {
            value = "<non-primitive>"
        }
    }
}
