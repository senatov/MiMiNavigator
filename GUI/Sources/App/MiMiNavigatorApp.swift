//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import SwiftUI

let log = LogMan.log

@main
struct MiMiNavigatorApp: App {
    @StateObject private var appState = AppState()  // single source of truth

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
            .environmentObject(appState)  // make AppState visible to the whole scene
            .focusable(true)
            .onAppear {
                // Initialize file lists, watchers, and restore state once at launch
                log.debug("App launched → initializing AppState")
                appState.initialize()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { log.info("Refresh button clicked") }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .padding(.horizontal, 2)
                            .padding(.vertical, 6)
                            .symbolEffect(.pulse)  // .bounce, .variableColor, .scale
                    }
                    .clipShape(Circle())
                    .offset(x: 3, y: 6)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { appState.revealLogFileInFinder() }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .padding(.horizontal, 2)
                            .padding(.vertical, 6)
                            .symbolEffect(.pulse)
                    }
                    .clipShape(Circle())
                    .offset(x: 3, y: 6)
                }
                ToolbarItem(placement: .status) {
                    HStack(spacing: 4) {
                        Text("🐈 Dev. Build:")
                            .font(.title2)
                            .foregroundColor(FilePanelStyle.blueSymlinkDirNameColor)
                        makeDevMark()
                            .foregroundColor(FilePanelStyle.dirNameColor)
                            .font(.title3)
                    }
                }
            }
        }
        .commands {
            AppCommands(appState: appState)
        }
    }

    // MARK: -
    private func makeDevMark() -> Text {
        log.info(#function + " - creating development mark")
        // Prefer reading from bundled file 'curr_version.asc'; fall back to Info.plist values
        let versionURL = Bundle.main.url(forResource: "curr_version", withExtension: "asc")
        let content: String
        if let url = versionURL, let versionString = try? String(contentsOf: url, encoding: .utf8) {
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

}
