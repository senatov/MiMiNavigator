//
//  MediaInfoPanelWindowDelegate.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AVKit
import AppKit
import SwiftUI

final class MediaInfoPanelWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = MediaInfoPanelWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            MediaInfoPanel.shared.stopVideoPlayback()
        }
    }
}
