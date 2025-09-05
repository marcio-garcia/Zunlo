//
//  Logger.swift
//  LoggingKit
//
//  Core, thread-safe logger with destinations, call-site metadata, and atomic writes.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

// import LoggingKit
//
// let console = Logger.ConsoleDestination(minLevel: .debug)
// let file = FileDestination(
//     options: .init(
//         directory: FileDestination.defaultLogsDirectory(),
//         baseFilename: "zunlo",
//         maxBytes: 5 * 1024 * 1024,
//         maxFiles: 7
//     ),
//     minLevel: .debug
// )
// let oslog = OSLogDestination(subsystem: "com.yourcompany.yourapp", minLevel: .debug)
//
// Logger.shared.replaceDestinations(with: [console, file, oslog])

// MARK: - Logger

public final class Logger: @unchecked Sendable {

    // MARK: Level

    public enum Level: Int, Comparable, CaseIterable, Sendable {
        case trace = 0, debug, info, warn, error, critical

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var short: String {
            switch self {
            case .trace:    return "TRACE"
            case .debug:    return "DEBUG"
            case .info:     return "INFO "
            case .warn:     return "WARN "
            case .error:    return "ERROR"
            case .critical: return "CRIT!"
            }
        }
    }

    // MARK: Entry + Metadata

    public struct Metadata: Sendable {
        public let fileID: String
        public let function: String
        public let line: UInt
        public let className: String?
        public let queueLabel: String
        public let threadID: UInt64
    }

    public struct Entry: Sendable {
        public let date: Date
        public let level: Level
        public let category: String?
        public let message: String
        public let metadata: Metadata
    }

    // MARK: Destinations

    public protocol Destination: AnyObject {
        var minLevel: Level { get set }
        /// Optional destination-level filtering. Return true to allow, false to drop.
        var predicate: (@Sendable (Entry) -> Bool)? { get set }
        func write(_ entry: Entry)
    }

    /// Console destination using a dedicated serial queue for atomic writes.
    public final class ConsoleDestination: Destination, @unchecked Sendable {
        public var minLevel: Level
        public var predicate: (@Sendable (Entry) -> Bool)?

        /// A single global queue ensures atomic, non-interleaved writes for all console logs.
        private static let writeQueue = DispatchQueue(label: "com.loggingkit.console.write", qos: .utility)

        public init(minLevel: Level = .debug, predicate: (@Sendable (Entry) -> Bool)? = nil) {
            self.minLevel = minLevel
            self.predicate = predicate
        }

        public func write(_ entry: Entry) {
            guard entry.level >= minLevel else { return }
            if let predicate, predicate(entry) == false { return }

            ConsoleDestination.writeQueue.async {
                let ts = formatTS(entry.date)
                let fileName = (entry.metadata.fileID as NSString).lastPathComponent
                let cat = entry.category.map { "[\($0)] " } ?? ""
                let cls = entry.metadata.className ?? fileName
                let fn  = entry.metadata.function
                let ln  = entry.metadata.line
                let q   = entry.metadata.queueLabel
                let tid = entry.metadata.threadID

                // Single, atomic write:
                let line = "\(ts) [\(entry.level.short)] \(cat)[\(cls) \(fn) @ \(fileName):\(ln)] " +
//                "| q=\(q) tid=\(tid) | " +
                "\(entry.message)\n"

                if let data = line.data(using: .utf8) {
                    // Use non-throwing write for widest compatibility
                    FileHandle.standardError.write(data)
                    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                    FileHandle.standardError.synchronizeFile()
                    #endif
                }
            }
        }
    }

    // MARK: Shared

    public static let shared = Logger()

    // MARK: Config

    /// Optional global filter applied before dispatching to destinations.
    public var globalFilter: (@Sendable (Entry) -> Bool)?

    // MARK: Internals

    private let stateQueue = DispatchQueue(label: "com.loggingkit.state", qos: .userInitiated)
    private var destinations: [Destination] = [ConsoleDestination()] // sensible default

    private init() {}

    // MARK: Destination management

    public func addDestination(_ destination: Destination) {
        stateQueue.sync { destinations.append(destination) }
    }

    public func replaceDestinations(with newDestinations: [Destination]) {
        stateQueue.sync { destinations = newDestinations }
    }

    // MARK: Logging API (core)

    public func log(
        _ message: @autoclosure () -> String,
        level: Level = .debug,
        category: String? = nil,
        owner: Any? = nil,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        let meta = Metadata(
            fileID: String(describing: fileID),
            function: String(describing: function),
            line: line,
            className: owner.map { String(describing: type(of: $0)) },
            queueLabel: String(cString: __dispatch_queue_get_label(nil)),
            threadID: Logger.currentThreadID()
        )

        let entry = Entry(date: Date(), level: level, category: category, message: message(), metadata: meta)

        if let globalFilter, globalFilter(entry) == false { return }

        // Snapshot destinations to avoid holding the lock while writing
        let sinks = stateQueue.sync { destinations }
        for d in sinks { d.write(entry) }
    }

    // MARK: Convenience per-level helpers

    public func trace(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                      fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .trace, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    public func debug(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                      fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .debug, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    public func info(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                     fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .info, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    public func warn(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                     fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .warn, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    public func error(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                      fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .error, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    public func critical(_ message: @autoclosure () -> String, category: String? = nil, owner: Any? = nil,
                         fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .critical, category: category, owner: owner, fileID: fileID, function: function, line: line)
    }

    // MARK: Utilities

    private static func currentThreadID() -> UInt64 {
        var tid: UInt64 = 0
        #if canImport(Darwin)
        pthread_threadid_np(nil, &tid)
        #endif
        return tid
    }
}

// MARK: - Opt-in sugar for classes/structs

/// Adopt `Loggable` for a one-liner `log()` that captures `self` as the `className`.
public protocol Loggable {}

public extension Loggable {
    @inlinable
    func log(_ message: @autoclosure () -> String,
             level: Logger.Level = .debug,
             category: String? = nil,
             fileID: StaticString = #fileID,
             function: StaticString = #function,
             line: UInt = #line) {
        Logger.shared.log(message(), level: level, category: category, owner: self,
                          fileID: fileID, function: function, line: line)
    }

    @inlinable func logTrace(_ message: @autoclosure () -> String, category: String? = nil,
                             fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .trace, category: category, fileID: fileID, function: function, line: line)
    }
    @inlinable func logDebug(_ message: @autoclosure () -> String, category: String? = nil,
                             fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .debug, category: category, fileID: fileID, function: function, line: line)
    }
    @inlinable func logInfo(_ message: @autoclosure () -> String, category: String? = nil,
                            fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .info, category: category, fileID: fileID, function: function, line: line)
    }
    @inlinable func logWarn(_ message: @autoclosure () -> String, category: String? = nil,
                            fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .warn, category: category, fileID: fileID, function: function, line: line)
    }
    @inlinable func logError(_ message: @autoclosure () -> String, category: String? = nil,
                             fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .error, category: category, fileID: fileID, function: function, line: line)
    }
    @inlinable func logCritical(_ message: @autoclosure () -> String, category: String? = nil,
                                fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .critical, category: category, fileID: fileID, function: function, line: line)
    }
}

// MARK: - Ultra-quick global helper (optional)

@inlinable
public func log(_ message: @autoclosure () -> String,
              level: Logger.Level = .debug,
              category: String? = nil,
              fileID: StaticString = #fileID,
              function: StaticString = #function,
              line: UInt = #line) {
    Logger.shared.log(message(), level: level, category: category,
                      owner: /* no owner in global helper */ nil,
                      fileID: fileID, function: function, line: line)
}
