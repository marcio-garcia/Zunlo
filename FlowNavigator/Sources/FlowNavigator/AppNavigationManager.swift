//
//  AppNavigationManager.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import Combine

@MainActor
final public class AppNavigationManager: ObservableObject {
    @Published public var sheet: SheetRoute?
    @Published public var fullScreen: FullScreenRoute?
    @Published public var dialog: DialogRoute?
    @Published public var path: [StackRoute] = []

    public init() {}
    
    public func navigate(to route: StackRoute) {
        path.append(route)
    }

    public func popToRoot() {
        path.removeAll()
    }

    public func showSheet(_ route: SheetRoute) {
        sheet = route
    }

    public func showFullScreen(_ route: FullScreenRoute) {
        fullScreen = route
    }

    public func showDialog(_ route: DialogRoute) {
        dialog = route
    }

    public func dismissSheet() { sheet = nil }
    public func dismissFullScreen() { fullScreen = nil }
    public func dismissDialog() { dialog = nil }
}
