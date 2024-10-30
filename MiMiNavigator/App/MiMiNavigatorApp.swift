//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import SwiftData
import SwiftUI


@main

// MARK: - -

struct MiMiNavigatorApp: App {
    @StateObject private var directoryMonitor = DualDirectoryMonitor(
        leftDirectory: URL(fileURLWithPath: "."),
        rightDirectory: URL(fileURLWithPath: "/"))

    var sharedModelContainer: ModelContainer = {
        CustomLogger.shared.logInfo(" ---- BEGIN ----")
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