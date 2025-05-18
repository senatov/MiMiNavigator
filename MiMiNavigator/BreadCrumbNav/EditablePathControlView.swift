//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.05.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import SwiftUI
import SwiftyBeaver

// MARK: - EditablePathControlView
struct EditablePathControlView: View {
    @ObservedObject var selected: SelectedDir
    var panelSide: PanelSide
    // MARK: - Initialization
    init(selectedDir: SelectedDir, panelSide: PanelSide) {
        self.selected = selectedDir
        self.panelSide = panelSide
    }
    // MARK: - View Body
    var body: some View {
        HStack(spacing: 2) {
            NavMnu1(selectedDir: selected, panelSide: panelSide)
            Spacer(minLength: 3)
            let pathItem = pathComponents()
            BreadCrumbView(selectedDir: selected, components: pathItem, panelSide: panelSide)
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
        )
    }
    // MARK: - Generate path components for breadcrumb navigation
    private func pathComponents() -> [EditablePathItem] {
        log.debug("pathComponents() called for panel: \(panelSide)")
        let url = selected.selectedFSEntity.url
        log.debug("Selected URL: \(url.path)")
        var components = url.pathComponents
        // Remove leading '/' only if there is more than one component
        if components.first == "/" && components.count > 1 {
            components.removeFirst()
        }
        var currentPath = url.isFileURL && url.path.hasPrefix("/") ? "/" : ""
        var items: [EditablePathItem] = []
        for component in components {
            // Skip empty components
            guard !component.isEmpty else { continue }
            // Build the correct path
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)
            let displayTitle: String
            // For root, replace component with a user-friendly name
            if currentPath == "/" {
                displayTitle = "Macintosh HD"
            } else {
                displayTitle = component
            }
            items.append(EditablePathItem(titleStr: displayTitle, pathStr: currentPath, icon: icon))
        }
        log.debug("Breadcrumb items count: \(items.count)")
        return items
    }
}
