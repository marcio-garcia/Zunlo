//
//  FileDestination.swift
//  LoggingKit
//
//  Destination that writes logs to rotating files atomically.
//

import Foundation

public final class FileDestination: Logger.Destination, @unchecked Sendable {
    public var minLevel: Logger.Level
    public var predicate: (@Sendable (Logger.Entry) -> Bool)?

    public struct Options {
        public var directory: URL
        public var baseFilename: String              // e.g., "app" -> app.log, app.1.log, ...
        public var maxBytes: Int64                   // active file max size before rotation
        public var maxFiles: Int                     // number of rotated files to keep (excludes the active file)

        public init(
            directory: URL = FileDestination.defaultLogsDirectory(),
            baseFilename: String = "app",
            maxBytes: Int64 = 5 * 1024 * 1024,      // 5 MB
            maxFiles: Int = 5
        ) {
            self.directory = directory
            self.baseFilename = baseFilename
            self.maxBytes = maxBytes
            self.maxFiles = max(1, maxFiles)
        }
    }

    // MARK: - Init

    private let options: Options
    private let writeQueue: DispatchQueue
    private var fileHandle: FileHandle?

    public init(
        options: Options = .init(),
        minLevel: Logger.Level = .debug,
        predicate: (@Sendable (Logger.Entry) -> Bool)? = nil
    ) {
        self.options = options
        self.minLevel = minLevel
        self.predicate = predicate
        self.writeQueue = DispatchQueue(label: "com.loggingkit.file.write.\(UUID().uuidString)", qos: .utility)

        prepareDirectory()
        openHandleIfNeeded()
    }

    deinit {
        try? fileHandle?.close()
    }

    // MARK: - Logger.Destination

    public func write(_ entry: Logger.Entry) {
        guard entry.level >= minLevel else { return }
        if let predicate, predicate(entry) == false { return }

        writeQueue.async {
            let ts = formatTS(entry.date)
            let fileName = (entry.metadata.fileID as NSString).lastPathComponent
            let cat = entry.category.map { "[\($0)] " } ?? ""
            let cls = entry.metadata.className ?? fileName
            let fn  = entry.metadata.function
            let ln  = entry.metadata.line
            let q   = entry.metadata.queueLabel
            let tid = entry.metadata.threadID

            let line = "\(ts) [\(entry.level.short)] \(cat)[\(cls) \(fn) @ \(fileName):\(ln)] | q=\(q) tid=\(tid) | \(entry.message)\n"

            guard let data = line.data(using: .utf8) else { return }

            // Rotate if needed, then append atomically
            self.rotateIfNeeded(addingBytes: Int64(data.count))
            self.append(data: data)
        }
    }

    // MARK: - Public helpers

    public var activeLogURL: URL { fileURL(index: nil) }

    public func rotatedLogURLs() -> [URL] {
        (1...options.maxFiles).compactMap { idx in
            let url = fileURL(index: idx)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    // MARK: - Internals

    private func prepareDirectory() {
        let fm = FileManager.default
        var dir = options.directory

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Exclude from iCloud/iTunes backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dir.setResourceValues(resourceValues)

        // On iOS, prefer completeUnlessOpen protection when possible (best-effort)
        #if os(iOS) || os(tvOS) || os(watchOS)
        try? fm.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: dir.path)
        #endif
    }

    private func openHandleIfNeeded() {
        if fileHandle != nil { return }
        let url = activeLogURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: url)
        _ = try? fileHandle?.seekToEnd()
    }

    private func append(data: Data) {
        openHandleIfNeeded()
        guard let fh = fileHandle else { return }
        do {
            try fh.seekToEnd()
            // Use non-throwing write for widest compatibility
            fh.write(data)
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            fh.synchronizeFile()
            #endif
        } catch {
            // If writing fails, attempt to reopen and retry once
            try? fileHandle?.close()
            fileHandle = nil
            openHandleIfNeeded()
            fileHandle?.write(data)
        }
    }

    private func rotateIfNeeded(addingBytes: Int64) {
        let url = activeLogURL
        let fm = FileManager.default

        let currentSize = (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        let willBeSize = currentSize + addingBytes
        guard willBeSize > options.maxBytes else { return }

        // Close before moving
        try? fileHandle?.close()
        fileHandle = nil

        // Remove the oldest
        let oldest = fileURL(index: options.maxFiles)
        if fm.fileExists(atPath: oldest.path) {
            try? fm.removeItem(at: oldest)
        }

        // Shift N-1 ... 1 upward
        if options.maxFiles > 1 {
            for i in stride(from: options.maxFiles - 1, through: 1, by: -1) {
                let src = fileURL(index: i)
                let dst = fileURL(index: i + 1)
                if fm.fileExists(atPath: src.path) {
                    try? fm.moveItem(at: src, to: dst)
                }
            }
        }

        // Move current -> .1
        if fm.fileExists(atPath: url.path) {
            try? fm.moveItem(at: url, to: fileURL(index: 1))
        }

        // Recreate empty active file and reopen
        fm.createFile(atPath: url.path, contents: nil)
        openHandleIfNeeded()
    }

    private func fileURL(index: Int?) -> URL {
        let name = index == nil
        ? "\(options.baseFilename).log"
        : "\(options.baseFilename).\(index!).log"
        return options.directory.appendingPathComponent(name, isDirectory: false)
    }

    // Default per-platform logs directory
    public static func defaultLogsDirectory() -> URL {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        #else
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        #endif
        return base.appendingPathComponent("Logs", isDirectory: true)
    }
}
