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
    private let barHeight: CGFloat = 30

    // MARK: -
    init(selectedSide: PanelSide) {
        log.info("BreadCrumbView init" + " for side \(selectedSide)")
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        log.info(#function + " for side \(panelSide)")
        /// Main breadcrumb container
        return HStack(alignment: .center, spacing: 4) {
            ForEach(pathComponents.indices, id: \.self) { index in
                breadcrumbItem(index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // растянуть и прижать влево
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(minHeight: barHeight, alignment: .center)
        .controlSize(.large)
    }

    // MARK: -
    private var pathComponents: [String] {
        log.info(#function + " for side \(panelSide)")
        let path = (panelSide == .left ? appState.leftPath : appState.rightPath)
        log.info(#function + " for side \(panelSide)" + " with path: \(path)")
        return path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: -
    @ViewBuilder
    private func breadcrumbItem(index: Int) -> some View {
        if index > 0 {
            Image(systemName: "arrowtriangle.forward")
                .renderingMode(.original)
                .foregroundColor(.secondary)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1)
                .contrast(1.12)
                .saturation(1.06)
                .onTapGesture {
                    log.info(#function)
                }
        }
        getMnuButton(index)
    }

    // MARK: - Breadcrumb Item
    private func getMnuButton(_ index: Int) -> some View {
        log.info(#function)
        return Button(action: { handlePathSelection(upTo: index) }) {
            Text(pathComponents[index]).font(.callout).foregroundColor(FilePanelStyle.blueSymlinkDirNameColor).padding(.vertical, 2)
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
            .replacingOccurrences(of: "///", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = (panelSide == .left ? appState.leftPath : appState.rightPath)
        // ⚠️ threat from recursive calls
        guard appState.toCanonical(from: newPath) != appState.toCanonical(from: currentPath) else {
            log.info("Path unchanged, skipping update")
            return
        }
        // Focus is updated by AppState.updatePath(_:for:)
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
        log.info("Task started for side \(panelSide) with path: \(path)")
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
        log.info("Task finished successfully")
    }
}