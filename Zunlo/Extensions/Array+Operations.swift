//
//  Array+Operations.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/2/25.
//

import Foundation

// Helper to remove duplicates by value
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
