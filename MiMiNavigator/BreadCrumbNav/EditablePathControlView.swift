//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.05.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import SwiftUI
import SwiftyBeaver

// MARK: -
/// -
struct EditablePathControlView: View {
    @ObservedObject var selected: SelectedDir
    var panelSide: PanelSide

    // MARK: -
    init(selectedDir: SelectedDir, panelSide: PanelSide) {
        self.selected = selectedDir
        self.panelSide = panelSide
    }

    // MARK: -
    var body: some View {
        HStack(spacing: 2) {
            NavMnu1(selectedDir: selected, panelSide: panelSide)
            Spacer(minLength: 3)
            let pathItem = pathComponents()
            BreadCrumbView(selectedDir: selected, components: pathItem, panelSide: panelSide )
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
        )
    }

    // MARK: - Generate path components
    private func pathComponents() -> [EditablePathItem] {
        log.debug(#function)
        let url = selected.selectedFSEntity.url
        var components = url.pathComponents
        if components.first == "/" { components.removeFirst() }

        var currentPath = "/"
        return components.map { component in
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)
            return EditablePathItem(titleStr: component, pathStr: currentPath, icon: icon)
        }
    }
}
