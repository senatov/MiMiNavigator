//
//  ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
// Description:

import SwiftUI
import SwiftyBeaver

// MARK: -
struct ConsoleCurrPath: View {
    // Initialize logger
    var body: some View {
        VStack {
        }
        .foregroundColor(.primary)  // System default color
        .padding()
    }
}

// MARK: -
@MainActor func openConsoleInActivePanelDirectory() {
    LogMan.log.info("openConsoleInActivePanelDirectory()")

    let directory =
        NSDocumentController.shared.recentDocumentURLs.first?.deletingLastPathComponent().path
                                        ?? FileManager.default.homeDirectoryForCurrentUser.path

    let script = """
        tell application "Terminal"
            do script "cd \(directory)"
            activate
        end tell
        """

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    task.launch()
}

// Example function where the button is created
@MainActor
func buildDownToolbar() -> some View {
    DownToolbarButtonView(
        title: "Console",
        systemImage: "apple.terminal",
        action: {
            LogMan.log.debug("Console button tapped")
            openConsoleInActivePanelDirectory()
        }
    )
}
