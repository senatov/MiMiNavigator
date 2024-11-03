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
    
    @StateObject private var directoryMonitor = DualDirectoryScanner(
        leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: URL(fileURLWithPath: "/Users/senat/Downloads"))
    
        // MARK: -
    init() {
        log.debug("Console logging")
        // Add Console Destination
        let console = ConsoleDestination()

        // Set base log format (without level symbol here)
        console.format = "$DHH:mm:ss$d ➤ $L ➤ $N.$F:$l ➤ $M"

        // Configure emoji icons based on log level
        func getLevelIcon(for level: SwiftyBeaver.Level) -> String {
            switch level {
            case .verbose:
                return "🔮➤" // Purple arrow for verbose
            case .debug:
                return "☘️➤" // Green arrow for debug
            case .info:
                return "🔹➤" // Blue arrow for info
            case .warning:
                return "🔸➤" // Orange arrow for warning
            case .error:
                return "💢➤" // Red arrow for error
            default:
                return "➤➤➤➤" // Default arrow
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
