    //
    //  DragSelectionResolver.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import AppKit
    import FileModelKit
    import SwiftUI

    struct DragSelectionResolver {
        @MainActor
        static func resolve(from appState: AppState, side: PanelSide) -> [URL] {
            var selectedPaths = appState.markedFiles(for: side)

            if selectedPaths.isEmpty {
                let selected = side == .left
                    ? appState.selectedLeftFile
                    : appState.selectedRightFile

                if let selected,
                   !ParentDirectoryEntry.isParentEntry(selected) {
                    selectedPaths = [selected.pathStr]
                }
            }

            return selectedPaths.map { URL(fileURLWithPath: $0) }
        }
    }
