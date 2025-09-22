//
//  ChatStreamState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/4/25.
//

import Foundation

enum ChatStreamState: Equatable {
    case idle
    case streaming(assistantId: UUID)
    case awaitingTools(responseId: String, assistantId: UUID?)
    case failed(String)
    case stopped(assistantId: UUID?)
    
    static func == (lhs: ChatStreamState, rhs: ChatStreamState) -> Bool {
        switch lhs {
        case .idle:
            if rhs == .idle {
                return true
            } else {
                return false
            }
        case .streaming(let assistantId):
            if case .streaming(let id) = rhs, assistantId == id {
                return true
            } else {
                return false
            }
        case .awaitingTools(let responseId, let assistantId):
            if case .awaitingTools(let respId, let assistId) = rhs,
                responseId == respId,
                assistId == assistantId {
                return true
            } else {
                return false
            }
        case .failed(let msg):
            if case .failed(let string) = rhs, msg == string {
                return true
            } else {
                return false
            }
        case .stopped(assistantId: let assistantId):
            if case .stopped(let assistId) = rhs, assistId == assistantId {
                return true
            } else {
                return false
            }
        }
    }
    
}
