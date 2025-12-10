//
// FavTreePopupController.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
@Observable
final class FavTreePopupController {
    private var popover: NSPopover?
    var isPresented: Bool = false  // Popup state

    // periphery:ignore
    @MainActor
    func show(
        for file: Binding<CustomFile>,
        expandedFolders: Binding<Set<String>>,
        panelSide: PanelSide,
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
            isPresented: Binding(
                get: { self.isPresented },
                set: { self.isPresented = $0 }
            )
        )
        .environment(appState)

        let hosting = NSHostingController(rootView: content)
        let pop = NSPopover()
        pop.contentViewController = hosting
        pop.behavior = .semitransient  // closes only on ESC or explicit action
        pop.animates = true
        pop.contentSize = NSSize(width: 360, height: 420)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        popover = pop
        isPresented = true

        // Popover will be closed via close() method
    }

}
