//
//  FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

//
//  FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//

import SwiftUI

/// Separate view to simplify type-checking of the main FileTableView.
/// Responsible only for rendering the LazyVStack of rows.
struct FileTableRowsView: View {
    @EnvironmentObject var appState: AppState
    let rows: [(offset: Int, element: CustomFile)]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void

    var body: some View {
        log.debug(#function)
        return LazyVStack(spacing: 0) {
            ForEach(rows, id: \.element.id) { pair in
                row(for: pair.element, index: pair.offset)
            }
        }
    }

    // MARK: - Row builder
    @ViewBuilder
    private func row(for file: CustomFile, index: Int) -> some View {
         FileRow(
            index: index,
            file: file,
            isSelected: selectedID == file.id,
            panelSide: panelSide,
            onSelect: { tapped in
                selectedID = tapped.id
                appState.focusedPanel = panelSide
                onSelect(tapped)
                log.info("Row tapped: \(tapped.nameStr) [\(tapped.id)] on <<\(panelSide)>>")
            },
            onFileAction: { action, f in
                log.debug(#function)
                handleFileAction(action, f)
            },
            onDirectoryAction: { action, f in
                log.debug(#function)
                handleDirectoryAction(action, f)
            }
        )
    }
}
