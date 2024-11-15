//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import Compression
import SwiftData
import SwiftUI
import SwiftyBeaver

let log = SwiftyBeaver.self

@main
struct MiMiNavigatorApp: App {
    // MARK: - -

    init() {
        log.debug("MiMiNavigatorApp initialized")

        // Add Console Destination
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss$d ➤ $L ➤ $N.$F:$l ➤ $M"

        // Configure emoji icons based on log level
        func getLevelIcon(for level: SwiftyBeaver.Level) -> String {
            switch level {
            case .verbose: return "🔮➤"
            case .debug: return "☘️➤"
            case .info: return "🔹➤"
            case .warning: return "🔸➤"
            case .error: return "💢➤"
            default: return "➤➤➤➤"
            }
        }
        // Customize level string for each log level
        console.levelString.verbose = getLevelIcon(for: .verbose) + " VERBOSE"
        console.levelString.debug = getLevelIcon(for: .debug) + " DEBUG"
        console.levelString.info = getLevelIcon(for: .info) + " INFO"
        console.levelString.warning = getLevelIcon(for: .warning) + " WARNING"
        console.levelString.error = getLevelIcon(for: .error) + " ERROR"
        log.addDestination(console)
        setupFileLogging()
    }

    // MARK: - -

    private func setupFileLogging() {
        log.debug("setupFileLogging()")
        let file = FileDestination()
        // Create log directory
        guard let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("MiMiNavigator", isDirectory: true) else {
            log.error("Failed to initialize file logging directory")
            print("Failed to initialize file logging directory")
            return
        }
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
            // Check the current log file size
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let logFileName = "MiMiNavigator_\(dateFormatter.string(from: Date())).log"
            file.logFileURL = logDirectory.appendingPathComponent(logFileName)
            if let currentLogURL = file.logFileURL, FileManager.default.fileExists(atPath: currentLogURL.path) {
                let fileSize = try FileManager.default.attributesOfItem(atPath: currentLogURL.path)[.size] as? UInt64 ?? 0
                if fileSize > 10 * 1024 * 1024 { 
                    try archiveAndClearLogFile(at: currentLogURL, in: logDirectory)
                }
            }
            log.addDestination(file)
            log.debug("File logging initialized at \(file.logFileURL?.path ?? "unknown path")")
            // Cleanup old ZIP files and logs
            try cleanUpOldZipFiles(in: logDirectory)
            try cleanUpOldLogs(in: logDirectory)

        } catch {
            log.error("Failed to setup file logging: \(error)")
            print("Error setting up file logging: \(error)")
        }
    }

    // MARK: - -

    private func archiveAndClearLogFile(at logFileURL: URL, in logDirectory: URL) throws {
        log.debug("archivingAndClearingLogFile()")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let zipFileName = "MiMiNavigatorLog_\(dateFormatter.string(from: Date())).zip"
        let zipFileURL = logDirectory.appendingPathComponent(zipFileName)
        // Compress log file into ZIP format
        try compressFile(at: logFileURL, to: zipFileURL)
        log.debug("Archived log file to \(zipFileURL.path)")
        // Remove old log after archiving
        try FileManager.default.removeItem(at: logFileURL)
        log.debug("Cleared original log file at \(logFileURL.path)")
    }

    // MARK: - - Custom function to compress data from a source file to a destination file using zlib

    private func compressFile(at sourceURL: URL, to destinationURL: URL) throws {
        log.debug("compressFile()")
        let source = try FileHandle(forReadingFrom: sourceURL)
        defer { source.closeFile() }

        let destination = try FileHandle(forWritingTo: destinationURL)
        defer { destination.closeFile() }

        let bufferSize = 64 * 1024

        while let bytesRead = try? source.read(upToCount: bufferSize), !bytesRead.isEmpty {
            let compressedData = compressData(bytesRead)
            destination.write(compressedData)
        }
    }

    // MARK: - - Custom compression function using zlib

    private func compressData(_ data: Data) -> Data {
        log.debug("compressData()")
        var compressedData = Data()
        data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            let sourceBuffer = UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: data.count)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }
            let compressedSize = compression_encode_buffer(destinationBuffer, data.count, sourceBuffer.baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            if compressedSize > 0 {
                compressedData.append(destinationBuffer, count: compressedSize)
            }
        }
        return compressedData
    }

    // MARK: - -

    private func cleanUpOldZipFiles(in directory: URL) throws {
        log.debug("cleanUpOldZipFiles()")
        let fileManager = FileManager.default
        let zipFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "zip" }
            .sorted { (file1: URL, file2: URL) in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
        let filesToDelete = zipFiles.dropFirst(3)
        for file in filesToDelete {
            try fileManager.removeItem(at: file)
            log.debug("Deleted old zip file: \(file.lastPathComponent)")
        }
    }

    // MARK: - -

    private func cleanUpOldLogs(in directory: URL) throws {
        log.debug("cleanUpOldLogs()")
        let fileManager = FileManager.default
        let twoHourAgo = Calendar.current.date(
            byAdding: .hour,
            value: -2,
            to: Date()
        ) ?? Date.distantPast
        let logFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "log" }
        for logFile in logFiles {
            let creationDate = try logFile.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            if creationDate < twoHourAgo {
                try fileManager.removeItem(at: logFile)
                log.debug("Deleted old log file: \(logFile.lastPathComponent)")
            }
        }
    }

    var sharedModelContainer: ModelContainer = {
        log.debug(" ---- BEGIN ----")
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            VStack {
                TotalCommanderResizableView()
                ConsoleCurrPath()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
