//
// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Lightweight row view to reduce type-checker complexity
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    @Environment(AppState.self) var appState
    
    // MARK: - Design Constants for selection colors (macOS style)
    private enum SelectionColors {
        // Active panel: system accent color (like Finder)
        static let activeFill = Color(nsColor: .selectedContentBackgroundColor)
        static let activeBorder = Color(nsColor: .keyboardFocusIndicatorColor).opacity(0.6)
        // Inactive panel: subtle gray (like unfocused Finder window)
        static let inactiveFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        static let inactiveBorder = Color(nsColor: .separatorColor)
    }
    
    // MARK: - Is this panel currently focused
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    var body: some View {
        EquatableView(value: file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0)) {
            // Zebra background stripes (macOS system colors)
            ZStack(alignment: .leading) {
                let zebraColors = NSColor.alternatingContentBackgroundColors
                let zebra = Color(nsColor: zebraColors[index % zebraColors.count])
                zebra.allowsHitTesting(false)

                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActivePanel ? SelectionColors.activeBorder : SelectionColors.inactiveBorder, lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                }

                rowContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .drawingGroup()
        .help(makeHelpTooltip())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded { _ in
                log.debug("[DOUBLE-CLICK] FileRow: index=\(index) name=\(file.nameStr) side=<<\(panelSide)>>")
                onDoubleClick(file)
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                log.debug("[SELECT-FLOW] 4️⃣ FileRow.simultaneousGesture: index=\(index) name=\(file.nameStr) side=<<\(panelSide)>>")
                log.debug("[SELECT-FLOW] 4️⃣ Calling onSelect closure...")
                onSelect(file)
                log.debug("[SELECT-FLOW] 4️⃣ onSelect returned")
            }
        )
        .animation(nil, value: isSelected)
        .transaction { txn in
            txn.disablesAnimations = true
        }
        .contextMenu {
            menuContent(
                for: file,
                onFileAction: onFileAction,
                onDirectoryAction: onDirectoryAction)
        }
        .id("\(panelSide)_\(String(describing: file.id))")
    }

    // MARK: - Context menu builder to simplify type-checking
    @ViewBuilder
    func menuContent(
    for file: CustomFile,
    onFileAction: @escaping (FileAction, CustomFile) -> Void,
    onDirectoryAction: @escaping (DirectoryAction, CustomFile) -> Void
    ) -> some View {
        if file.isDirectory {
            DirectoryContextMenu(file: file) { action in
                onDirectoryAction(action, file)
            }
        } else {
            FileContextMenu(file: file) { action in
                onFileAction(action, file)
            }
        }
    }

    // MARK: - Text color for secondary columns (size, date)
    private var secondaryTextColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.85) : Color(nsColor: .secondaryLabelColor)
    }
    
    private var tertiaryTextColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.7) : Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: - Extracted row content
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            // Name column (expands)
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel)
                .frame(maxWidth: .infinity, alignment: .leading)
            // vertical separator
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color(nsColor: .separatorColor))
                .padding(.vertical, 2)
            // Size column (here showing type string as in original)
            Text(file.fileObjTypEnum)
                .foregroundStyle(secondaryTextColor)
                .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)
            // vertical separator
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color(nsColor: .separatorColor))
                .padding(.vertical, 2)
            // Date column
            Text(file.modifiedDateFormatted)
                .foregroundStyle(tertiaryTextColor)
                .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
    }

    // MARK: - Tooltip helper
    private func makeHelpTooltip() -> String {
        var details = ""
        if file.isDirectory {
            details = "📁 Directory"
        } else {
            details = "📄 File"
        }
        let idPart = file.id
        let datePart = file.modifiedDateFormatted
        let typePart = file.fileObjTypEnum
        return "\(details)\n🆔 \(idPart)\n📅 \(datePart)\n🧩 \(typePart)"
    }
}
