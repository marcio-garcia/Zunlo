//
//  TestDBFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift
@testable import Zunlo

enum TestDBFactory {
    /// Creates a unique in-memory configuration for each test.
    static func makeInMemoryConfig(label: String = UUID().uuidString) -> Realm.Configuration {
        Realm.Configuration(inMemoryIdentifier: "ZunloTests-\(label)")
    }

    static func makeActor(label: String = UUID().uuidString) -> DatabaseActor {
        let cfg = makeInMemoryConfig(label: label)
        return DatabaseActor(config: cfg, keepAliveAnchor: true)
    }
}
