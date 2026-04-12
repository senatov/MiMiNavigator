//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


import AVFoundation
import AVKit
import AppKit
import SwiftyBeaver
import UniformTypeIdentifiers


@MainActor
extension MediaInfoPanel {
    // MARK: - Actions
    @objc func copyPathAction() {
        guard let url = currentURL else { return }
        copyToPasteboard(url.path)
    }

    @objc func copyAllAction() {
        guard let text = textView?.string else { return }
        copyToPasteboard(text)
    }

    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    @objc func revealAction() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func closeAction() { hide() }
}
