//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import SwiftData
import SwiftUI
import SwiftyBeaver

let log = SwiftyBeaver.self

@main

// MARK: - -

struct MiMiNavigatorApp: App {
    
    @ObservedObject
    private var directoryMonitor = DualDirectoryMonitor(
        leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly"),
        rightDirectory: URL(fileURLWithPath: "/Users/senat/Downloads"))

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

    // MARK: -

    init() {
        log.debug("Console logging")
        let console = ConsoleDestination()
        console.minLevel = .verbose
        console.format = "$DHH:mm:ss$d $L $M"
        log.addDestination(console)
        // File logging (optional)
        let file = FileDestination()
        file.minLevel = .info
        log.addDestination(file)
    }

    // MARK: -

    var body: some Scene {
        WindowGroup {
            VStack {
                TotalCommanderResizableView(directoryMonitor: directoryMonitor)
                ConsoleCurrPath()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
