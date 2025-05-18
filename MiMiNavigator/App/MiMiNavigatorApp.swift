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

/// -
@main
struct MiMiNavigatorApp: App {

    let devMark: Text = {
        let versionPath = Bundle.main.path(forResource: ".version", ofType: nil)
        let content: String
        if let versionPath, let versionString = try? String(contentsOfFile: versionPath, encoding: .utf8) {
            content = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            log.debug("Loaded version from .version file: \(content)")
        } else {
            content = "Mimi Navigator — Version unavailable"
            log.error("Failed to load .version file.")
        }
        return Text(content)
    }()

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
                    .navigationTitle("Mimi Navigator")
                ConsoleCurrPath()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        log.debug("Refresh button clicked")
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                ToolbarItem(placement: .status) {
                    Text("🛠 Dev Build: ")
                        .font(.caption)
                        .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))
                        + devMark.foregroundColor(Color(#colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)))
                        .font(.caption)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
