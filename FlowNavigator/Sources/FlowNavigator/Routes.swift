//
//  Routes.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/7/25.
//

public protocol AppSheetRoute: Identifiable, Equatable {}
public protocol AppFullScreenRoute: Identifiable, Equatable {}
public protocol AppDialogRoute: Identifiable, Equatable {}
public protocol AppStackRoute: Hashable {}
