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
    var sharedModelContainer: ModelContainer = makeSharedModelContainer()
    
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
        // Prefer reading from bundled file 'curr_version.asc'; fall back to Info.plist values
        let versionURL = Bundle.main.url(forResource: "curr_version", withExtension: "asc")
        let content: String
        if let url = versionURL,
           let versionString = try? String(contentsOf: url, encoding: .utf8)
        {
            let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            content = trimmed
            log.info("Loaded version from 'curr_version.asc' file: '\(content)'")
        } else {
            // Fallback: build version string from Info.plist values
            let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            if let s = short, let b = build {
                content = "v\(s) (\(b))"
                log.info("Fallback to Info.plist version: '\(content)'")
            } else if let s = short {
                content = "v\(s)"
                log.info("Fallback to Info.plist short version: '\(content)'")
            } else if let b = build {
                content = "build \(b)"
                log.info("Fallback to Info.plist build: '\(content)'")
            } else {
                content = "Mimi Navigator — cannot determine version"
                log.error("Failed to load version from file and Info.plist.")
            }
        }
        return Text(content)
    }

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
