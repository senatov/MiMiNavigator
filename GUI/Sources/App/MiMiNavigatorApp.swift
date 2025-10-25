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
    
        // MARK: -
    init() {
        LogMan.initializeLogging()
        log.debug("---- Logger initialized ------")
    }
    
        // MARK: -
    var body: some Scene {
        WindowGroup {
            VStack {
                TotalCommanderResizableView()
                ConsoleCurrPath()
            }
            .environmentObject(appState)
            .onAppear { appDelegate.bind(appState) }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { log.debug("Refresh button clicked") }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 13, weight: .semibold))
                            .help("Refresh")
                            .accessibilityLabel("Refresh")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { appState.revealLogFileInFinder() }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 13, weight: .semibold))
                            .help("Reveal log file in Finder")
                            .accessibilityLabel("Reveal log file in Finder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                ToolbarItem(placement: .status) {
                    HStack(spacing: 8) {
                            // Badge icon styled for macOS 26 "liquid glass" look
                        Text("🐈")
                            .font(.title3)
                            .padding(4)
                            .background(Material.ultraThin, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("DEV BUILD")
                                .font(.caption2)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            makeDevMark()
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundColor(FilePanelStyle.dirNameColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Material.ultraThin, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    .help("Current development build version")
                }
            }
            .toolbarBackground(Material.thin, for: ToolbarPlacement.windowToolbar)
            .toolbarBackgroundVisibility(Visibility.visible, for: ToolbarPlacement.windowToolbar)
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
