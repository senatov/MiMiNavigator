//
//  CommandLineView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//

import SwiftUI

struct ConsoleCurrPath: View {
    var body: some View {
        VStack {
        }
        .foregroundColor(.primary) // System default color
        .padding()
    }
}

func openConsoleInDirectory(_ directory: String) {
    // Step 1: Launch Terminal
    let launchTask = Process()
    launchTask.launchPath = "/usr/bin/open"
    launchTask.arguments = ["/System/Applications/Utilities/Terminal.app"]
    launchTask.launch()

    // Step 2: Set position and size of Terminal window
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Small delay to ensure Terminal is open
        // Define main window dimensions
        let mainAppWidth = 800 // Set your main window's width
        let mainAppHeight = 600 // Set your main window's height
        let terminalHeight = 100 // Approximate height for 5 lines

        let script = """
        tell application "Terminal"
            do script "cd \(directory)"
            activate
            delay 0.5  -- Wait for terminal to become active
            set bounds of front window to {0, \(mainAppHeight), \(mainAppWidth), \(mainAppHeight + terminalHeight)}
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.launch()
    }
}
