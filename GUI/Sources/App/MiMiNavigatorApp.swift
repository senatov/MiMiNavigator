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
    @StateObject private var appState = AppState()
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
            DuoFilePanelView()
                .environmentObject(appState)
                .onAppear { appDelegate.bind(appState) }
                .toolbarBackground(Material.thin, for: ToolbarPlacement.windowToolbar)
                .toolbarBackgroundVisibility(Visibility.visible, for: ToolbarPlacement.windowToolbar)
                .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        Task { await BookmarkStore.shared.stopAll() }
                    }
                }
                .toolbar {
                    toolBarItemRefresh()
                    toolBarItemMagnify()
                    toolBarItemBuildInfo()
                }
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
        }
    }

    // MARK: -
    fileprivate func toolBarItemRefresh() -> ToolbarItem<(), some View> {
        log.debug(#function)
        return ToolbarItem(placement: .automatic) {
            Button(action: { log.debug("Refresh button clicked") }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .font(.system(size: 13, weight: .semibold))
                    .help("Refresh")
                    .accessibilityLabel("Refresh")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.horizontal, 12)
        }
    }

    // MARK: -
    fileprivate func toolBarItemMagnify() -> ToolbarItem<(), some View> {
        log.debug(#function)
        return ToolbarItem(placement: .automatic) {
            Button(action: { appState.revealLogFileInFinder() }) {
                Image(systemName: "doc.text.magnifyingglass")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .font(.system(size: 13, weight: .semibold))
                    .help("Reveal log file in Finder")
                    .accessibilityLabel("Reveal log file in Finder")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.horizontal, 12)
        }
    }

    // MARK: -
    fileprivate func toolBarItemBuildInfo() -> ToolbarItem<(), some View> {
        log.debug(#function)
        return ToolbarItem(placement: .status) {
            HStack(spacing: 8) {
                Text("🐈")
                    .font(.caption2)
                    .padding(8)
                    .background(Circle().fill(Color.yellow.opacity(0.1)))
                    .overlay(
                        Circle().strokeBorder(Color.blue.opacity(0.8), lineWidth: 0.04)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("DEV BUILD")
                        .font(.caption2)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    makeDevMark()
                        .font(.caption2)
                        .foregroundStyle(FilePanelStyle.dirNameColor)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 1)
            .background(.yellow.opacity(0.05), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.red, lineWidth: 0.8)
            )
            .help("Current development build version")
        }
    }

    // MARK: -
    private func makeDevMark() -> Text {
        log.debug(#function + " - creating dev mark")
        let versionURL = Bundle.main.url(forResource: "curr_version", withExtension: "asc")
        let content: String
        if let url = versionURL, let versionString = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
            content = trimmed
            log.debug("loaded version from file: '\(content)'")
        } else {
            let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            if let s = short, let b = build {
                content = "v\(s) (\(b))"
                log.debug("fallback to Info.plist: '\(content)'")
            } else if let s = short {
                content = "v\(s)"
                log.debug("fallback to short version: '\(content)'")
            } else if let b = build {
                content = "build \(b)"
                log.debug("fallback to build: '\(content)'")
            } else {
                content = "Mimi Navigator — cannot determine version"
                log.error("failed to load version")
            }
        }
        return Text(content)
    }
}
