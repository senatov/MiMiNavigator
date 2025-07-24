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

// MARK: -
@main
struct MiMiNavigatorApp: App {
    @StateObject private var appState = AppState()

    // MARK: -
    init() {
        LogMan.initializeLogging()
        log.info("---- Logger initialized ------")
    }

    // MARK: -
    var body: some Scene {
        WindowGroup {
            VStack {
                TotalCommanderResizableView()
                    .navigationTitle("Mimi Navigator")
                ConsoleCurrPath()
            }
            .environmentObject(appState)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        log.info("Refresh button clicked")
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .padding(.horizontal, 2)
                            .padding(.vertical, 6)

                    }
                    .clipShape(Circle())
                    .offset(x: 3, y: 6)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        appState.revealLogFileInFinder()
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .padding(.horizontal, 2)
                            .padding(.vertical, 6)
                    }
                    .clipShape(Circle())
                    .offset(x: 3, y: 6)
                }
                ToolbarItem(placement: .status) {
                    Text("🐈‍⬛ Dev. Build: ")
                        .font(.title2)
                        .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))
                        + makeDevMark().foregroundColor(Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1)))
                        .font(.title3)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }


    // MARK: -
    private func makeDevMark() -> Text {
        let versionPath = Bundle.main.path(forResource: "curr_version.asc", ofType: nil)
        let content: String
        if let versionPath, let versionString = try? String(contentsOfFile: versionPath, encoding: .utf8) {
            content = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            log.info("Loaded version from .version file: \(content)")
        } else {
            content = "Mimi Navigator — Version unavailable"
            log.error("Failed to load .version file.")
        }
        return Text(content)
    }


    // MARK: -
    var sharedModelContainer: ModelContainer = makeSharedModelContainer()

    private static func makeSharedModelContainer() -> ModelContainer {
        log.info(#function)
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
