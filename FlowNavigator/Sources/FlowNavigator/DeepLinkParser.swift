//
//  DeepLinkParser.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation

struct DeepLinkParser {
    static func parse(url: URL) -> DeepLink? {
        guard url.scheme == "myapp" else { return nil }

        let path = url.pathComponents.filter { $0 != "/" }

        if path.first == "task", path.count == 2, let uuid = UUID(uuidString: path[1]) {
            return .taskDetail(id: uuid)
        }

        if path.first == "edit-task", path.count == 2, let uuid = UUID(uuidString: path[1]) {
            return .editTask(id: uuid)
        }

        if path.first == "add-task" {
            return .addTask
        }

        if path.first == "login" {
            return .login
        }

        if path.first == "onboarding" {
            return .onboarding
        }

        if path.first == "settings" {
            return .showSettings
        }

        return nil
    }
}
