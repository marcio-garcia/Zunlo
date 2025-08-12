//
//  XCTAssert.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import XCTest

func XCTAssertEqualAsync<T: Equatable>(
    _ expr: @escaping () async -> T,
    _ expected: T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let value = await expr()
    XCTAssertEqual(value, expected, file: file, line: line)
}

func XCTAssertNilAsync<T>(
    _ expr: @escaping () async -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let value = await expr()
    XCTAssertNil(value, file: file, line: line)
}
