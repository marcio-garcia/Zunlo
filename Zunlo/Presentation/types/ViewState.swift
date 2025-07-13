//
//  ViewState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

enum ViewState {
    case loading
    case loaded
    case empty
    case error(_ message: String)
}
