//
//  DetailedDecodingError.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/28/25.
//

enum DetailedDecodingError: Error, CustomStringConvertible {
    case decodingError(path: String, value: Any?, underlying: Error)
    
    var description: String {
        switch self {
        case .decodingError(let path, let value, let underlying):
            return "Decoding failed at '\(path)' with value: \(String(describing: value)). Underlying error: \(underlying)"
        }
    }
}
