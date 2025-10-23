    //
    //  FileRow.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

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
            // Zebra background stripes (Finder-like)
        ZStack(alignment: .leading) {
            let zebra = index.isMultiple(of: 2) ? Color.white : Color.gray.opacity(0.08)
            zebra.allowsHitTesting(false)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
            }
            
            rowContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .help(makeHelpTooltip())
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                        // Centralized selection and focus
                    onSelect(file)
                }
        )
        .overlay(highlightedSquare(isSelected))
        .shadow(color: isSelected ? .gray.opacity(0.07) : .clear, radius: 4, x: 1, y: 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        .contextMenu {
            menuContent(
                for: file,
                onFileAction: onFileAction,
                onDirectoryAction: onDirectoryAction)
        }
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
            Divider().padding(.vertical, 2)
                // Size column (here showing type string as in original)
            Text(file.fileObjTypEnum)
                .foregroundStyle(.secondary)
                .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)
                // vertical separator
            Divider().padding(.vertical, 2)
                // Date column
            Text(file.modifiedDateFormatted)
                .foregroundStyle(.tertiary)
                .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
    }
    
        // MARK: - Highlight helper (forward to the one in FileTableView through a local copy)
    @ViewBuilder
    private func highlightedSquare(_ isLineSelected: Bool) -> some View {
        if isLineSelected {
            Rectangle().inset(by: 0.2).stroke(FilePanelStyle.blueSymlinkDirNameColor.gradient, lineWidth: 0.7)
        } else {
            EmptyView()
        }
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
