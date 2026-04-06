//
//   FileTableView+Selection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Combine
import FileModelKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers


extension FileTableView {
    // MARK: - Selection Helpers
    func isParentRow(_ file: CustomFile) -> Bool {
        ParentDirectoryEntry.isParentEntry(file) || file.nameStr == ".."
    }

    /// Compare a visible row with a selectedID, handling synthetic parent row correctly
    func isSameRow(_ file: CustomFile, id: CustomFile.ID?) -> Bool {
        guard let id else { return false }

        if isParentRow(file) {
            return cachedSortedRows.first(where: { isParentRow($0) })?.id == id
        }

        return file.id == id
    }

    /// Current selected file ID from AppState.
    var selectedFileIDFromState: CustomFile.ID? {
        guard let selected = appState.panel(panelSide).selectedFile else {
            return nil
        }

        if isParentRow(selected) {
            return cachedSortedRows.first(where: { isParentRow($0) })?.id
        }

        return selected.id
    }

    func updateSelectedIndex(for newID: CustomFile.ID?) {
        if let id = newID,
            let rowIndex = cachedSortedRows.firstIndex(where: { $0.id == id })
        {
            appState.setSelectedIndex(rowIndex, for: panelSide)
        } else {
            appState.setSelectedIndex(0, for: panelSide)
        }
    }
}
