//
//  MiMiNavigatorApp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import AppKit
import SwiftUI

let log = LogMan.log

@main
struct MiMiNavigatorApp: App {
    @StateObject private var appState = AppState()  // single source of truth
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    // MARK: -
    init() {
        LogMan.initializeLogging()
        log.debug("---- Logger initialized ------")
        Task { await BookmarkStore.shared.restoreAll() }
    }

    // MARK: -
    var body: some Scene {
        WindowGroup {
            VStack {
                DownPanelView()
                ConsoleCurrPath()
            }
            .environmentObject(appState)
            .onAppear { appDelegate.bind(appState) }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { log.debug("Refresh button clicked") }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 13, weight: .semibold))
                            .help("Refresh")
                            .accessibilityLabel("Refresh")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { appState.revealLogFileInFinder() }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 13, weight: .semibold))
                            .help("Reveal log file in Finder")
                            .accessibilityLabel("Reveal log file in Finder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                }
                ToolbarItem(placement: .status) {
                    HStack(spacing: 8) {
                        // Badge icon styled for macOS 26 "liquid glass" look
                        Text("🐈")
                            .font(.caption2)
                            .padding(8)
                            .background(Circle().fill(Color.yellow.opacity(0.1)))
                            .overlay(
                                Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.3)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DEV BUILD")
                                .font(.caption2)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            makeDevMark()
                                .font(.caption2)
                                .foregroundColor(FilePanelStyle.dirNameColor)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 0)
                    .background(.yellow.opacity(0.05), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.red, lineWidth: 0.8)
                    )
                    .help("Current development build version")
                }
            }
            .toolbarBackground(Material.thin, for: ToolbarPlacement.windowToolbar)
            .toolbarBackgroundVisibility(Visibility.visible, for: ToolbarPlacement.windowToolbar)
            .onChange(of: scenePhase) {
                if scenePhase == .background {
                    Task { await BookmarkStore.shared.stopAll() }
                }
            }
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
        }
    }

    // MARK: -
    private func makeDevMark() -> Text {
        log.debug(#function + " - creating development mark")
        // Prefer reading from bundled file 'curr_version.asc'; fall back to Info.plist values
        let versionURL = Bundle.main.url(forResource: "curr_version", withExtension: "asc")
        let content: String
        if let url = versionURL, let versionString = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            content = trimmed
            log.debug("Loaded version from 'curr_version.asc' file: '\(content)'")
        } else {
            // Fallback: build version string from Info.plist values
            let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            if let s = short, let b = build {
                content = "v\(s) (\(b))"
                log.debug("Fallback to Info.plist version: '\(content)'")
            } else if let s = short {
                content = "v\(s)"
                log.debug("Fallback to Info.plist short version: '\(content)'")
            } else if let b = build {
                content = "build \(b)"
                log.debug("Fallback to Info.plist build: '\(content)'")
            } else {
                content = "Mimi Navigator — cannot determine version"
                log.error("Failed to load version from file and Info.plist.")
            }
        }
        return Text(content)
    }

}
