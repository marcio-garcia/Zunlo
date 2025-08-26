//
//  RemoteEntity.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//
import Foundation

public protocol RemoteEntity {
    var id: UUID { get }
    var updatedAt: Date { get }
    var updatedAtRaw: String? { get }   // raw cursor echo (microseconds)
    var deletedAt: Date? { get }
    var version: Int? { get }
}
