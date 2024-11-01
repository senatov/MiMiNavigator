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
        let console = ConsoleDestination()
        console.minLevel = .verbose
        console.format = "$DHH:mm:ss$d $L $M"
        log.addDestination(console)
        // File logging (optional)
        let file = FileDestination()
        file.minLevel = .info
        log.addDestination(file)
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
