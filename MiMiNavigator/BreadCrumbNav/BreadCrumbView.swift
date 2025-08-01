//
//  BreadCrumbView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: - Breadcrumb trail UI component for representing navigation path
struct BreadCrumbView: View {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide

    // MARK: -
    init(selectedSide: PanelSide) {
        log.info("BreadCrumbView init" + " for side \(selectedSide)")
        self.panelSide = selectedSide
    }


    // MARK: -
    var body: some View {
        log.info(#function + " for side \(panelSide)")
        return HStack(spacing: 4) {
            ForEach(pathComponents.indices, id: \.self) { index in
                breadcrumbItem(index: index)
            }
        }
    }


    // MARK: -
    private var pathComponents: [String] {
        let path = (panelSide == .left ? appState.leftPath : appState.rightPath)
        log.info(#function + " for side \(panelSide)" + " with path: \(path)")
        return path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
    }


    // MARK: - Breadcrumb Item
    @ViewBuilder
    private func breadcrumbItem(index: Int) -> some View {
        if index > 0 {
            Image(systemName: "chevron.forward").foregroundColor(.secondary)
        }
        Button(action: { handlePathSelection(upTo: index) }) {
            Text(pathComponents[index]).font(.callout).foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .help("Click to open: /" + pathComponents.prefix(index + 1).joined(separator: "/"))
        .contextMenu {
            Button("Copy path") {
                let fullPath = "/" + pathComponents.prefix(index + 1).joined(separator: "/")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullPath, forType: .string)
            }
        }
    }


    // MARK: - Handle Selection
    private func handlePathSelection(upTo index: Int) {
        log.info(#function + " for index \(index) on side \(panelSide)")
        let newPath = ("/" + pathComponents.prefix(index + 1).joined(separator: "/"))
            .replacingOccurrences(of: "//", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = (panelSide == .left ? appState.leftPath : appState.rightPath)
        // ⚠️ Защита от бесконечного вызова
        guard appState.toCanonical(from: newPath) != appState.toCanonical(from: currentPath) else {
            log.debug("Path unchanged, skipping update")
            return
        }
        appState.focusedSide = panelSide
        appState.updatePath(newPath, for: panelSide)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await performDirectoryUpdate(for: panelSide, path: newPath)
            semaphore.signal()
        }
    }


    // MARK: -
    @MainActor
    private func performDirectoryUpdate(for panelSide: PanelSide, path: String) async {
        log.debug("Task started for side \(panelSide) with path: \(path)")
        if panelSide == .left {
            await appState.scanner.setLeftDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .left)
            await appState.refreshLeftFiles()
        }
        else {
            await appState.scanner.setRightDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .right)
            await appState.refreshRightFiles()
        }
        log.debug("Task finished successfully")
    }
}
