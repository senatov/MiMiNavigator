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

    var body: some View {
        log.info(#function)
        return VStack {
        }
        .foregroundColor(.primary)  // System default color
        .padding()
    }
}

// MARK: -
func openConsoleInDirectory(_ directoryStr: String) {
    log.info(#function)
    let launchTask = Process()
    launchTask.launchPath = "/usr/bin/open"
    launchTask.arguments = ["/System/Applications/Utilities/Terminal.app"]
    launchTask.launch()
    // Step 2: Set position and size of Terminal window
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Small delay to ensure Terminal is open
        let script = """
            tell application "Terminal"
                do script "cd \(directoryStr)"
                activate
                delay 0.7 -- Wait for terminal to become active
            end tell
            """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.launch()
    }
}
