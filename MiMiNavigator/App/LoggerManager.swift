import Compression
import Foundation
import SwiftyBeaver

/// -
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
            case .critical: return "💀"
            case .fault: return "👻"
            }
        }
        console.levelString.verbose = getLevelIcon(for: .verbose) + " VERBOSE"
        console.levelString.debug = getLevelIcon(for: .debug) + " DEBUG"
        console.levelString.info = getLevelIcon(for: .info) + " INFO"
        console.levelString.warning = getLevelIcon(for: .warning) + " WARNING"
        console.levelString.error = getLevelIcon(for: .error) + " ERROR"
        console.levelString.critical = getLevelIcon(for: .error) + " CRITICAL"
        console.levelString.fault = getLevelIcon(for: .error) + " FAULT"
        log.addDestination(console)
        setupFileLogging()
    }

    // MARK: -
    private static func setupFileLogging() {
        let file = FileDestination()
        let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/MiMiNavigator")
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
}
