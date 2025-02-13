import Compression
import Foundation
import SwiftyBeaver

final class LogMan {
    static let log = SwiftyBeaver.self

    // MARK: -
    static func initializeLogging() {
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss$d ➤ $L ➤ $N.$F:$l ➤ $M"
        // Customize log level icons
        func getLevelIcon(for level: SwiftyBeaver.Level) -> String {
            switch level {
            case .verbose: return "🔮"
            case .debug: return "☘️"
            case .info: return "🔹"
            case .warning: return "🔸"
            case .error: return "💢"
            case .critical: return "🍎"
            case .fault: return "🪗"
            }
        }
        console.levelString.verbose = getLevelIcon(for: .verbose) + " VERBOSE"
        console.levelString.debug = getLevelIcon(for: .debug) + " DEBUG"
        console.levelString.info = getLevelIcon(for: .info) + " INFO"
        console.levelString.warning = getLevelIcon(for: .warning) + " WARNING"
        console.levelString.error = getLevelIcon(for: .error) + " ERROR"
        log.addDestination(console)
        setupFileLogging()
    }

    // MARK: -
    private static func setupFileLogging() {
        let file = FileDestination()
        let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs")
        if let logDirectory = logDirectory {
            do {
                try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
                let logFileName = "MiMiNavigator_\(Date().timeIntervalSince1970).log"
                file.logFileURL = logDirectory.appendingPathComponent(logFileName)
                log.addDestination(file)
            } catch {
                log.error("Failed to setup file logging: \(error)")
            }
        }
    }

    // MARK: -
    private func cleanUpOldZipFiles(in directory: URL) throws {
        LogMan.log.debug("cleanUpOldZipFiles()")
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
            LogMan.log.debug("Deleted old zip file: \(file.lastPathComponent)")
        }
    }

    // MARK: -
    private func archiveAndClearLogFile(at logFileURL: URL, in logDirectory: URL) throws {
        LogMan.log.debug("archivingAndClearingLogFile()")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let zipFileName = "MiMiNavigatorLog_\(dateFormatter.string(from: Date())).zip"
        let zipFileURL = logDirectory.appendingPathComponent(zipFileName)
        // Compress log file into ZIP format
        try compressFile(at: logFileURL, to: zipFileURL)
        LogMan.log.debug("Archived log file to \(zipFileURL.path)")
        // Remove old log after archiving
        try FileManager.default.removeItem(at: logFileURL)
        LogMan.log.debug("Cleared original log file at \(logFileURL.path)")
    }

    // MARK: - Custom compression function using zlib
    private func compressData(_ data: Data) throws -> Data {
        LogMan.log.debug("compressData()")
        var compressedData = Data()
        return try data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                throw NSError(domain: "CompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data buffer"])
            }
            let sourceBuffer = UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: data.count)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }
            let compressedSize = compression_encode_buffer(
                destinationBuffer, data.count, sourceBuffer.baseAddress!, data.count, nil, COMPRESSION_ZLIB
            )
            guard compressedSize > 0 else {
                throw NSError(domain: "CompressionError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to compress data"])
            }
            compressedData.append(destinationBuffer, count: compressedSize)
            LogMan.log.debug("Compression successful: original \(data.count) bytes → compressed \(compressedSize) bytes")
            return compressedData
        }
    }

    // MARK: - Custom function to compress data from a source file to a destination file using zlib
    private func compressFile(at sourceURL: URL, to destinationURL: URL) throws {
        LogMan.log.debug("compressFile()")
        let source = try FileHandle(forReadingFrom: sourceURL)
        defer { source.closeFile() }
        let destination = try FileHandle(forWritingTo: destinationURL)
        defer { destination.closeFile() }
        let bufferSize = 64 * 1024
        while let bytesRead = try? source.read(upToCount: bufferSize), !bytesRead.isEmpty {
            if let compressedData = try? compressData(bytesRead) {
                destination.write(compressedData)
            } else {
                LogMan.log.error("Failed to compress data from \(sourceURL.path)")
            }
        }
    }
}
