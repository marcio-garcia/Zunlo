//
//  OSLogDestination.swift
//  LoggingKit
//
//  Destination that routes entries to Apple's Unified Logging system (OSLog).
//

import Foundation
#if canImport(os)
import os

public final class OSLogDestination: Logger.Destination, @unchecked Sendable {
    public var minLevel: Logger.Level
    public var predicate: (@Sendable (Logger.Entry) -> Bool)?

    private let subsystem: String
    private var cache = [String: os.Logger]()     // category -> logger
    private let lock = NSLock()

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "app",
        minLevel: Logger.Level = .debug,
        predicate: (@Sendable (Logger.Entry) -> Bool)? = nil
    ) {
        self.subsystem = subsystem
        self.minLevel = minLevel
        self.predicate = predicate
    }

    public func write(_ entry: Logger.Entry) {
        guard entry.level >= minLevel else { return }
        if let predicate, predicate(entry) == false { return }

        let category = entry.category ?? (entry.metadata.className ?? "general")
        let logger = loggerForCategory(category)

        let file = (entry.metadata.fileID as NSString).lastPathComponent
        let cls  = entry.metadata.className ?? file
        let fn   = entry.metadata.function
        let ln   = entry.metadata.line

        let msg = "\(entry.level.short) [\(cls) \(fn) @ \(file):\(ln)] | \(entry.message)"

        switch entry.level {
        case .trace, .debug:
            logger.debug("\(msg, privacy: .public)")
        case .info:
            logger.info("\(msg, privacy: .public)")
        case .warn:
            logger.notice("\(msg, privacy: .public)")
        case .error:
            logger.error("\(msg, privacy: .public)")
        case .critical:
            logger.fault("\(msg, privacy: .public)")
        }
    }

    private func loggerForCategory(_ category: String) -> os.Logger {
        lock.lock(); defer { lock.unlock() }
        if let l = cache[category] { return l }
        let l = os.Logger(subsystem: subsystem, category: category)
        cache[category] = l
        return l
    }
}
#endif
