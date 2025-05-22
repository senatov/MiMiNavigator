//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.05.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import SwiftUI
import SwiftyBeaver

// MARK: - EditablePathControlView
struct EditablePathControlView: View, CustomStringConvertible {

    @StateObject var selection = SelectedDir()
    var panelSide: PanelSide

    // MARK: - Initialization
    init(selectedDir: SelectedDir, panelSide: PanelSide) {
        self.panelSide = panelSide
    }

    // MARK: - View Body
    var body: some View {
        log.debug(#function)
        return HStack(spacing: 2) {
            NavMnu1(panelSide: panelSide)
            Spacer(minLength: 3)
            let pathItem = getPathItems()
            BreadCrumbView(components: pathItem, panelSide: panelSide)
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
        )
    }

    // MARK: -
    private func getPathURL() -> URL? {
        guard let url = selection.selectedFSEntity?.url else {
            log.error("selectedFSEntity is nil — returning nil URL.")
            return nil
        }
        return url
    }

    // MARK: -
    private func createEditablePathItems(from url: URL) -> [EditablePathItem] {
        log.debug("Selected URL: \(url.path)")
        var items: [EditablePathItem] = []
        var components = url.pathComponents
        if components.first == "/" && components.count > 1 {
            components.removeFirst()
        }
        var currentPath = url.isFileURL && url.path.hasPrefix("/") ? "/" : ""
        for component in components {
            guard !component.isEmpty else { continue }
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)
            let displayTitle = currentPath == "/" ? "Macintosh HD" : component
            items.append(EditablePathItem(titleStr: displayTitle, pathStr: currentPath, icon: icon))
        }
        return items
    }

    // MARK: -
    private func getPathItems() -> [EditablePathItem] {
        log.debug(#function)
        guard let url = getPathURL() else {
            return []
        }
        let items = createEditablePathItems(from: url)
        log.debug("Breadcrumb items count: \(items.count)")
        return items
    }

    // MARK: -
    nonisolated var description: String {
        "description"
    }

}
