import AppKit
//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import SwiftUI
import SwiftyBeaver

/// Breadcrumb trail UI component for representing navigation path
struct BreadCrumbView: View {
    @ObservedObject var selected: SelectedDir
    var components: [EditablePathItem]
    var panelSide: PanelSide

    // MARK: -
    init(selectedDir: SelectedDir, components: [EditablePathItem], panelSide: PanelSide) {
        self.selected = selectedDir
        self.components = components
        self.panelSide = panelSide
    }

    // MARK: - Body
    var body: some View {
        breadcrumbItems
    }

    // MARK: - Breadcrumb Items
    private var breadcrumbItems: some View {
        ForEach(Array(components.enumerated()), id: \.element.pathStr) { index, item in
            breadcrumbItem(index: index, item: item)
        }
    }

    // MARK: - Breadcrumb Item
    /// Renders single breadcrumb item with optional separator
    /// - Parameters:
    ///   - index: Position of the item in the breadcrumb trail
    ///   - item: Logical entity representing the folder level
    /// - Returns: SwiftUI View of the breadcrumb entry
    @ViewBuilder
    private func breadcrumbItem(index: Int, item: EditablePathItem) -> some View {
        if index > 0 {
            breadcrumbSeparator()
        }
        breadcrumbButton(for: item)
    }

    // MARK: - Separator View
    @ViewBuilder
    private func breadcrumbSeparator() -> some View {
        Image(systemName: "chevron.forward.dotted.chevron.forward")
            .onTapGesture {
                log.debug("Forward: clicked breadcrumb separator")
            }
            .symbolRenderingMode(.multicolor)
    }

    // MARK: - Breadcrumb Button
    @ViewBuilder
    private func breadcrumbButton(for item: EditablePathItem) -> some View {
        Button(action: { handlePathSelection(for: item) }) {
            EditablePathDirIcon(item: item, pathStr: selected.selectedFSEntity.pathStr)
        }
        .buttonStyle(.link)
    }

    // MARK: - Selection Logic
    private func handlePathSelection(for item: EditablePathItem) {
        withAnimation(.easeInOut(duration: 0.4)) {
            selected.selectedFSEntity = CustomFile(path: item.pathStr)
        }
    }
}
