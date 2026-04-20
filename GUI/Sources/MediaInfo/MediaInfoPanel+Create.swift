//
//  MediaInfoPanel+Create.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import AVKit
import SwiftUI

@MainActor
extension MediaInfoPanel {
    func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: LayoutConstants.panelSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.level = .normal
        panel.titlebarAppearsTransparent = false
        panel.toolbarStyle = .unified
        panel.animationBehavior = .default
        panel.tabbingMode = .disallowed
        panel.standardWindowButton(.closeButton)?.keyEquivalent = "\u{1b}"
        panel.minSize = LayoutConstants.minPanelSize
        panel.delegate = MediaInfoPanelWindowDelegate.shared
        PanelTitleHelper.applyIconTitle(
            to: panel,
            systemImage: "info.circle",
            title: "Media􀅴 & Convert"
        )

        panel.contentView = NSHostingView(rootView: MediaInfoPanelView(controller: self))
        panel.center()
        self.panel = panel
    }
}








