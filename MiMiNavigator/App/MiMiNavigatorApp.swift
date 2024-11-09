//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftData
import SwiftUI
import SwiftyBeaver

let log = SwiftyBeaver.self

@main
struct MiMiNavigatorApp: App {
    // MARK: -

    init() {
        log.debug("Console logging")

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

        // Add the console to SwiftyBeaver
        log.addDestination(console)

        // Setup File Logging
        setupFileLogging()
    }

    private func setupFileLogging() {
        let file = FileDestination()

        if let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("MiMiNavigator", isDirectory: true) {
            do {
                // Try creating the directory if it doesn't exist
                try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)

                // Set log file path
                file.logFileURL = logDirectory.appendingPathComponent("MiMiNavigator.log")
                log.addDestination(file)

                log.debug("File logging initialized at \(file.logFileURL?.path ?? "unknown path")")
                print("Log file path: \(file.logFileURL?.path ?? "unknown path")")

            } catch {
                log.error("Failed to create log directory: \(error)")
                print("Error creating log directory: \(error)")
            }
        } else {
            log.error("Failed to initialize file logging directory")
            print("Failed to initialize file logging directory")
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
