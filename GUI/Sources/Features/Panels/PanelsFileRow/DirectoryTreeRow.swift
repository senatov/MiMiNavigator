// DirectoryTreeRow.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single row used by DirectoryTreeView.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Directory Tree Row
struct DirectoryTreeRow: View {
    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager
    let file: CustomFile
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isMarked: Bool
    let isEmptyDirectory: Bool
    let isExpandableDirectory: Bool
    let isLoadingSubtree: Bool
    let panelSide: FavPanelSide
    @Bindable var layout: ColumnLayoutModel
    let onToggle: () -> Void
    let onToggleSubtree: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onDrop: ([CustomFile]) -> Bool
    @State private var isDropTargeted = false

    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            nameCell
            ForEach(layout.fixedColumns.indices, id: \.self) { index in
                let spec = layout.fixedColumns[index]
                dividerSpacer
                fixedCell(spec)
            }
        }
        .frame(height: FilePanelStyle.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleClick)
        .simultaneousGesture(TapGesture(count: 1).onEnded { handleSingleClick() })
        .contextMenu { contextMenuContent }
        .modifier(dropModifier)
        .onDrag {
            dragDropManager.startDrag(files: [file], from: panelSide, appState: appState)
            return NSItemProvider(object: file.urlValue as NSURL)
        }
    }

    // MARK: - Cells
    private var nameCell: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(depth) * 16)
            disclosureControl
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(isEmptyDirectory ? 0.55 : 1)
            Text(file.nameStr)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(nameForegroundStyle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(width: layout.nameWidth, alignment: .leading)
        .clipped()
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if isLoadingSubtree {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.55)
                .frame(width: 12, height: 16)
        } else {
            Button(action: handleDisclosureClick) {
                Image(systemName: disclosureIcon)
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 12, height: 16)
                    .contentShape(Rectangle())
                    .opacity(disclosureOpacity)
            }
            .buttonStyle(.plain)
            .disabled(!isDirectory || isEmptyDirectory)
            .opacity(isDirectory ? 1 : 0)
        }
    }

    private func fixedCell(_ spec: ColumnSpec) -> some View {
        Text(text(for: spec.id))
            .font(spec.id == .permissions ? .system(size: 11, design: .monospaced) : .system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: spec.width, alignment: spec.id.alignment)
            .clipped()
    }

    private var dividerSpacer: some View {
        Color.clear
            .frame(width: 14)
            .allowsHitTesting(false)
    }

    // MARK: - State
    private var isDirectory: Bool {
        isExpandableDirectory
    }

    private var disclosureIcon: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var disclosureOpacity: Double {
        guard isDirectory else { return 0 }
        return isEmptyDirectory ? 0.25 : 1
    }

    private var nameForegroundStyle: Color {
        if isEmptyDirectory {
            return Color(nsColor: .secondaryLabelColor).opacity(0.62)
        }
        return Color(nsColor: .labelColor)
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.22)
            } else if isMarked {
                Color.accentColor.opacity(0.12)
            } else if isDropTargeted {
                Color.accentColor.opacity(0.14)
            } else {
                Color.clear
            }
        }
    }

    private var dropModifier: DropTargetModifier {
        DropTargetModifier(
            isValidTarget: isDirectory,
            isDropTargeted: $isDropTargeted,
            onDrop: onDrop,
            onTargetChange: { isDropTargeted = $0 }
        )
    }

    private func text(for col: ColumnID) -> String {
        switch col {
        case .name: return file.nameStr
        case .dateModified: return file.modifiedDateFormatted
        case .size: return file.displaySizeFormatted
        case .kind: return file.kindFormatted
        case .permissions: return file.permissionsFormatted
        case .owner: return file.ownerFormatted
        case .childCount: return file.childCountFormatted
        case .dateCreated: return file.creationDateFormatted
        case .dateLastOpened: return file.lastOpenedFormatted
        case .dateAdded: return file.dateAddedFormatted
        case .group: return file.groupNameFormatted
        }
    }

    private func handleSingleClick() {
        onSelect()
        let modifiers = currentClickModifiers()
        appState.handleClickWithModifiers(on: file, modifiers: modifiers)
        if modifiers == .none, isDirectory {
            onToggle()
        }
    }

    private func handleDisclosureClick() {
        guard isDirectory, !isEmptyDirectory else { return }
        onToggleSubtree()
    }

    private func currentClickModifiers() -> ClickModifiers {
        guard let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) else {
            return .none
        }
        if flags.contains(.command) { return .command }
        if flags.contains(.shift) { return .shift }
        return .none
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if appState.markedCount(for: panelSide) > 0 {
            MultiSelectionContextMenu(
                markedCount: appState.markedCount(for: panelSide),
                panelSide: panelSide,
                isOptionHeld: optionHeld
            ) { action in
                CntMenuCoord.shared.handleMultiSelectionAction(action, panel: panelSide, appState: appState)
            }
        } else if isExpandableDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                CntMenuCoord.shared.handleDirectoryAction(action, for: file, panel: panelSide, appState: appState)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                CntMenuCoord.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
            }
        }
    }
}
