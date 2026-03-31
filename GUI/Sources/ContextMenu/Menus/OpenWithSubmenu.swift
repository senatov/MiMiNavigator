// OpenWithSubmenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Submenu for "Open With" action - shows available applications

import AppKit
import SwiftUI
import FileModelKit

/// Submenu showing applications that can open the selected file.
/// Applications are snapshotted during initialization to keep the submenu stable.
@MainActor
struct OpenWithSubmenu: View {
    private let snapshot: Snapshot
    private let menuID: String

    init(file: CustomFile, apps: [AppInfo]) {
        snapshot = Snapshot(file: file, apps: apps)
        menuID = snapshot.menuID

        log.debug("[OpenWithSubmenu] init id='\(menuID)' \(snapshot.debugSignature)")
    }

    // MARK: - Body
    var body: some View {
        Menu {
            menuContent
        } label: {
            menuLabel
        }
        .id(menuID)
        .onAppear {
            log.debug("[OpenWithSubmenu] appear id='\(menuID)' \(snapshot.debugSignature)")
        }
        .onDisappear {
            log.debug("[OpenWithSubmenu] disappear id='\(menuID)' \(snapshot.debugSignature)")
        }
    }

    // MARK: - Menu Content
    @ViewBuilder
    private var menuContent: some View {
        if snapshot.apps.isEmpty {
            emptyStateView
        } else {
            appButtonsSection
        }

        utilityButtonsSection
    }

    private var menuLabel: some View {
        Label("Open With", systemImage: "arrow.up.right.square")
    }

    private var appButtonsSection: some View {
        Group {
            appButtons
            Divider()
        }
    }

    private var emptyStateView: some View {
        Text("No compatible applications found")
            .foregroundStyle(.secondary)
            .onAppear(perform: logEmptyState)
    }

    private var utilityButtonsSection: some View {
        Group {
            otherButton
            Divider()
            appStoreButton
        }
    }

    private func logEmptyState() {
        log.debug("[OpenWithSubmenu] empty state id='\(menuID)' file='\(snapshot.fileName)'")
    }

    @ViewBuilder
    private var appButtons: some View {
        ForEach(snapshot.apps) { app in
            appButton(for: app)
        }
    }

    private func appButton(for app: AppInfo) -> some View {
        Button {
            open(with: app)
        } label: {
            appRow(for: app)
        }
    }

    private var otherButton: some View {
        Button("Other...", action: openWithOther)
    }

    private var appStoreButton: some View {
        Button("App Store...", action: openInAppStore)
    }

    @ViewBuilder
    private func appRow(for app: AppInfo) -> some View {
        Label {
            rowTitle(for: app)
        } icon: {
            Image(nsImage: app.icon)
        }
        .id(rowID(for: app))
        .onAppear {
            logAppRow(app)
        }
    }

    // MARK: - Constants
    private var defaultSuffix: String { "(Default)" }

    private func rowID(for app: AppInfo) -> String {
        "\(menuID)|\(app.bundleIdentifier)"
    }

    @ViewBuilder
    private func rowTitle(for app: AppInfo) -> some View {
        HStack {
            Text(app.name)

            if app.isDefault {
                Text(defaultSuffix)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions
    private func openWithOther() {
        log.debug("[OpenWithSubmenu] other id='\(menuID)' file='\(snapshot.fileName)'")
        OpenWithService.shared.showOpenWithPicker(for: snapshot.fileURL)
    }

    private func openInAppStore() {
        let query = makeAppStoreQuery()

        log.debug("[OpenWithSubmenu] appStore id='\(menuID)' file='\(snapshot.fileName)' ext='\(snapshot.fileExtension)'")
        log.debug("[OpenWithSubmenu] appStoreQuery id='\(menuID)' value='\(query)'")

        openAppStore(searchQuery: query)
    }

    private func open(with app: AppInfo) {
        log.debug("[OpenWithSubmenu] open id='\(menuID)' app='\(app.name)' file='\(snapshot.fileName)'")
        OpenWithService.shared.openFile(snapshot.fileURL, with: app)
    }

    private func logAppRow(_ app: AppInfo) {
        log.debug("[OpenWithSubmenu] row id='\(menuID)' bundle='\(app.bundleIdentifier)' default=\(app.isDefault) file='\(snapshot.fileName)'")
    }

    // MARK: - Private
    private func makeAppStoreQuery() -> String {
        snapshot.fileExtension.isEmpty ? "file opener" : "\(snapshot.fileExtension) file"
    }

    private func openAppStore(searchQuery: String) {
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            log.error("[OpenWithSubmenu] failed to encode App Store query id='\(menuID)' file='\(snapshot.fileName)'")
            return
        }

        let urlString = "macappstore://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?q=\(encodedQuery)"

        guard let appStoreURL = URL(string: urlString) else {
            log.error("[OpenWithSubmenu] failed to build App Store URL id='\(menuID)' file='\(snapshot.fileName)'")
            return
        }

        NSWorkspace.shared.open(appStoreURL)
    }
}

// MARK: - Snapshot
private extension OpenWithSubmenu {
    struct Snapshot {
        let fileName: String
        let fileURL: URL
        let fileExtension: String
        let apps: [AppInfo]
        let menuID: String
        let debugSignature: String

        init(file: CustomFile, apps: [AppInfo]) {
            fileName = file.nameStr
            fileURL = file.urlValue
            fileExtension = file.fileExtension
            self.apps = apps
            menuID = Self.makeMenuID(fileURL: fileURL, apps: apps)
            debugSignature = Self.makeDebugSignature(fileName: fileName, menuID: menuID, apps: apps)
        }

        private static func makeMenuID(fileURL: URL, apps: [AppInfo]) -> String {
            let bundles = apps.map(\.bundleIdentifier).joined(separator: ",")
            return "openwith|\(fileURL.path)|\(bundles)"
        }

        private static func makeDebugSignature(fileName: String, menuID: String, apps: [AppInfo]) -> String {
            "menuID='\(menuID)' file='\(fileName)' apps=\(apps.count)"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Right-click for Open With submenu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        OpenWithSubmenu(file: CustomFile(path: "/Users/senat/test.txt"), apps: [])
    }
}
