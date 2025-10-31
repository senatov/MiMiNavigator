//
//  FavTreePopoverController.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
final class FavTreePopoverController: ObservableObject {
    private var popover: NSPopover?

    // periphery:ignore
    @MainActor
    func show(
        for file: Binding<CustomFile>,
        expandedFolders: Binding<Set<String>>,
        side: PanelSide,
        relativeTo button: NSView,
        appState: AppState
    ) {

        if popover?.isShown == true {
            popover?.performClose(nil)
            return
        }

        let content = FavTreePopupView(
            file: file,
            expandedFolders: expandedFolders,
            manageWindow: false
        )
        .environmentObject(appState)

        let hosting = NSHostingController(rootView: content)
        let pop = NSPopover()
        pop.contentViewController = hosting
        pop.behavior = .transient  // closes on click outside or ESC
        pop.animates = true
        pop.contentSize = NSSize(width: 360, height: 420)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        popover = pop
    }

    func close() {
        popover?.performClose(nil)
    }
}
