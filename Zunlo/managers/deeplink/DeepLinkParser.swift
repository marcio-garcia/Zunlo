//
//  DeepLinkParser.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation

public struct DeepLinkParser {
    static public func parse(url: URL) -> DeepLink? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            let host = components.host
        else {
            return nil
        }
        
        var path = components.path.split(separator: "/")
        
        switch scheme {
        case "zunloapp":
            switch host {
            case "supabase":
                switch path.removeFirst() {
                case "magic-link":
                    return .magicLink(url)
                default:
                    return nil
                }
            case "page":
                switch path.removeFirst() {
                case "edit-task":
                    let id = path.removeFirst()
                    guard let uuid = UUID(uuidString: String(id)) else {
                        return nil
                    }
                    return .editTask(id: uuid)
                default:
                    return nil
                }
            default:
                return nil
            }
            
        default:
            return nil
        }
    }
}
