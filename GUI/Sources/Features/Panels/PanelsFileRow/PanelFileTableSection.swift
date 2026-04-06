// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Feature flag: use NSTableView for large directories
/// When true, uses high-performance NSTableView instead of SwiftUI LazyVStack.
/// NSTableView handles 100k+ files without lag.
private let useNSTableView = false  // Back to SwiftUI

// MARK: - Panel file table section container

struct PanelFileTableSection: View {
    @Environment(AppState.self) var appState

    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let onPanelTap: (FavPanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    // Use singleton ColumnLayoutStore — avoids recreating ColumnLayoutModel on every SwiftUI rebuild
    private var columnLayout: ColumnLayoutModel {
        ColumnLayoutStore.shared.layout(for: panelSide)
    }

    private var currentFilesVersion: Int {
        panelSide == .left ? appState.leftFilesVersion : appState.rightFilesVersion
    }

    private var filesViewIdentity: Int {
        var hasher = Hasher()
        hasher.combine(panelSide)
        hasher.combine(currentFilesVersion)
        hasher.combine(files.count)
        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.nameStr)
            hasher.combine(file.pathStr)
            hasher.combine(file.isDirectory)
            hasher.combine(file.isParentEntry)
            hasher.combine(file.cachedDirectorySize)
            hasher.combine(file.sizeInBytes)
            hasher.combine(file.sizeIsExact)
            hasher.combine(file.modifiedDate?.timeIntervalSince1970 ?? 0)
            hasher.combine(String(describing: file.securityState))
        }
        return hasher.finalize()
    }

    // MARK: - Body
    var body: some View {
        Group {
            if useNSTableView {
                // High-performance NSTableView for large directories
                FileTableViewHybrid(
                    panelSide: panelSide,
                    files: files,
                    filesVersion: currentFilesVersion,
                    selectedID: $selectedID,
                    layout: columnLayout,
                    onSelect: handleSelection,
                    onDoubleClick: onDoubleClick
                )
                .id(filesViewIdentity)
            } else {
                // Original SwiftUI implementation
                FileTableView(
                    panelSide: panelSide,
                    files: files,
                    selectedID: $selectedID,
                    layout: columnLayout,
                    onSelect: handleSelection,
                    onDoubleClick: onDoubleClick
                )
                .id(filesViewIdentity)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    // set focus
                    if appState.focusedPanel != panelSide {
                        appState.focusedPanel = panelSide
                    }
                    // plain click anywhere on panel → clear marks if no modifier keys held
                    let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                        .subtracting([.function, .numericPad])
                    let isPlain = mods.isEmpty || mods == .capsLock
                    if isPlain && appState.markedCount(for: panelSide) > 0 {
                        appState.unmarkAll(on: panelSide)
                        log.debug("[PanelFileTableSection] tap → marks nuked on \(panelSide)")
                    }
                }
        )
        .animation(nil, value: selectedID)
        .transaction { txn in
            txn.disablesAnimations = true
        }
    }

    // MARK: - Selection handler
    private func handleSelection(_ file: CustomFile) {
        if appState.focusedPanel != panelSide {
            log.debug("[PanelFileTableSection] activating panel on selection: \(panelSide)")
            onPanelTap(panelSide)
        }

        log.debug("[PanelFileTableSection] handleSelection: \(file.nameStr)")

        if appState.focusedPanel != panelSide {
            appState.focusedPanel = panelSide
        }

        // IMPORTANT: update selectedID immediately so SwiftUI highlight updates
        selectedID = file.id
        // Notify listeners
        notifyWillSelect(file)
        // Forward to external selection logic (SelectionManager / AppState)
        onSelect(file)
    }

    // MARK: - Notifications
    private func notifyWillSelect(_ file: CustomFile) {
        log.debug(#function)
        NotificationCenter.default.post(
            name: .panelWillSelectFile,
            object: nil,
            userInfo: [
                "panelSide": panelSide,
                "fileID": file.id,
                "fileName": file.nameStr,
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
}
