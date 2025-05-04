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
struct MiMiNavigatorApp: App {

    // MARK: -
    init() {
        LogMan.initializeLogging()
    }

    // MARK: -
    var sharedModelContainer: ModelContainer = {
        log.debug(#function)
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: -
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
