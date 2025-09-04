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

// MARK: - MiMiNavigatorApp

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
                        .foregroundColor(FilePanelStyle.blueSymlinkDirNameColor) + makeDevMark()
                        .foregroundColor(FilePanelStyle.dirNameColor)
                        .font(.title3)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: -
    private func makeDevMark() -> Text {
        log.info(#function + " - creating development mark")
        let versionPath = Bundle.main.path(forResource: "curr_version.asc", ofType: nil)
        let content: String
        if let versionPath,
            let versionString = try? String(contentsOfFile: versionPath, encoding: .utf8) {
            content = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            log.info("Loaded version from 'curr_version.asc' file: '\(content)'")
        } else {
            content = "Mimi Navigator — cannot find version file"
            log.error("Failed to load 'curr_version.asc' file.")
        }
        return Text(content)
    }

    // MARK: -
    var sharedModelContainer: ModelContainer = makeSharedModelContainer()

    // MARK: -
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
