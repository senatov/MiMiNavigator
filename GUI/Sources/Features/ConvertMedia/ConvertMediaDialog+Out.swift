//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

extension ConvertMediaDialog {

    
    func performConvert() {
        guard isValid else { return }
        log.info("[ConvertMediaDialog] convert \(file.nameStr) → \(targetPreset.rawValue)")
        onConvert(targetPreset, outputURL)
    }

    func chooseOutputDir() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.directoryURL = URL(fileURLWithPath: outputDir)
            if await SystemPanelPresenter.response(for: panel) == .OK, let url = panel.url {
                outputDir = url.path
            }
        }
    }
}
