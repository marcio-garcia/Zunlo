//
//  AppNavigationManager.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

@MainActor
final public class AppNavigationManager: ObservableObject {
    @Published private var stackPaths: [UUID: [StackRoute]] = [:]
    @Published private var sheetRoutes: [UUID: SheetRoute] = [:]
    @Published private var fullScreenRoutes: [UUID: FullScreenRoute] = [:]
    @Published private var dialogRoutes: [UUID: DialogRoute] = [:]
    
    public init() {}
    
    // MARK: - NavigationStack
    
    public func pathBinding(for viewID: UUID) -> Binding<[StackRoute]> {
        Binding(
            get: { self.stackPaths[viewID, default: []] },
            set: { newValue in self.stackPaths[viewID] = newValue }
        )
    }

    public func navigate(to route: StackRoute, for viewID: UUID) {
        print("🚀 Navigating to \(route) for view \(viewID)")
        var path = stackPaths[viewID, default: []]
        path.append(route)
        stackPaths[viewID] = path
    }

    public func popToRoot(for viewID: UUID) {
        stackPaths[viewID] = []
    }
    
    // MARK: - Sheet
    
    public func showSheet(_ route: SheetRoute, for viewID: UUID) {
        sheetRoutes[viewID] = route
    }

    public func dismissSheet(for viewID: UUID) {
        sheetRoutes[viewID] = nil
    }

    public func sheetBinding(for viewID: UUID) -> Binding<SheetRoute?> {
        return Binding(
            get: { self.sheetRoutes[viewID] },
            set: { newValue in
                if newValue == nil {
                    self.dismissSheet(for: viewID)
                } else if let route = newValue {
                    self.showSheet(route, for: viewID)
                }
            }
        )
    }

    // MARK: - Full Screen

    public func showFullScreen(_ route: FullScreenRoute, for viewID: UUID) {
        fullScreenRoutes[viewID] = route
    }

    public func dismissFullScreen(for viewID: UUID) {
        fullScreenRoutes[viewID] = nil
    }

    public func fullScreenBinding(for viewID: UUID) -> Binding<FullScreenRoute?> {
        Binding(
            get: { self.fullScreenRoutes[viewID] },
            set: { newValue in
                if newValue == nil {
                    self.dismissFullScreen(for: viewID)
                } else if let route = newValue {
                    self.showFullScreen(route, for: viewID)
                }
            }
        )
    }

    // MARK: - Dialog
    
    public func showDialog(_ route: DialogRoute, for viewID: UUID) {
        dialogRoutes[viewID] = route
    }

    public func dismissDialog(for viewID: UUID) {
        dialogRoutes[viewID] = nil
    }

    public func isDialogPresented(for viewID: UUID) -> Binding<Bool> {
        Binding(
            get: { self.dialogRoutes[viewID] != nil },
            set: { if !$0 { self.dismissDialog(for: viewID) } }
        )
    }

    public func dialogRoute(for viewID: UUID) -> DialogRoute? {
        dialogRoutes[viewID]
    }
}
