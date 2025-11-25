//
// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Equatable wrapper to avoid unnecessary recomputation on divider drags
private struct EquatableView<Value: Hashable, Content: View>: View {
    let value: Value
    let content: () -> Content
    @MainActor var body: some View { content().id(value) }
}

// MARK: - Lightweight row view to reduce type-checker complexity
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        EquatableView(value: file.id.hashValue ^ (isSelected ? 1 : 0)) {
            // Zebra background stripes (Finder-like)
            ZStack(alignment: .leading) {
                let zebra = index.isMultiple(of: 2) ? Color.white : Color.gray.opacity(0.08)
                zebra.allowsHitTesting(false)

                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(FilePanelStyle.yellowSelRowFill) // pale yellow per spec
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FilePanelStyle.blueSymlinkDirNameColor, lineWidth: FilePanelStyle.selectedBorderWidth)
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
        .onTapGesture {
            log.debug("[SELECT-FLOW] 4️⃣ FileRow.onTapGesture: index=\(index) name=\(file.nameStr) side=<<\(panelSide)>>")
            log.debug("[SELECT-FLOW] 4️⃣ Calling onSelect closure...")
            onSelect(file)
            log.debug("[SELECT-FLOW] 4️⃣ onSelect returned")
        }
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

    // MARK: - Extracted row content
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            // Name column (expands)
            FileRowView(file: file, panelSide: panelSide)
            .frame(maxWidth: .infinity, alignment: .leading)
            // vertical separator
            Rectangle()
            .frame(width: 1)
            .foregroundStyle(Color(nsColor: .separatorColor))
            .padding(.vertical, 2)
            // Size column (here showing type string as in original)
            Text(file.fileObjTypEnum)
            .foregroundStyle(.secondary)
            .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)
            // vertical separator
            Rectangle()
            .frame(width: 1)
            .foregroundStyle(Color(nsColor: .separatorColor))
            .padding(.vertical, 2)
            // Date column
            Text(file.modifiedDateFormatted)
            .foregroundStyle(.tertiary)
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
