//
//  PushTokensRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import Foundation

protocol PushTokensRemoteStore {
    func fetchAll() async throws -> [PushTokenRemote]
    func save(_ remote: PushTokenRemote) async throws -> [PushTokenRemote]
    func update(_ remote: PushTokenRemote) async throws -> [PushTokenRemote]
    func delete(_ remote: PushTokenRemote) async throws -> [PushTokenRemote]
    func deleteAll(for userId: UUID) async throws -> [PushTokenRemote]
}
