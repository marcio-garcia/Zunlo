//
//  EncodingStrategy.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/30/25.
//

public enum ServerOwnedEncoding { case include, exclude }

public extension CodingUserInfoKey {
    static let serverOwnedEncodingStrategy = CodingUserInfoKey(rawValue: "serverOwnedEncodingStrategy")!
}
