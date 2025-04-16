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
func openConsoleInDirectory(_ directory: String) {
  LogMan.log.info("openConsoleInDirectory()")  // Log for method tracking
  // Step 1: Launch Terminal
  let launchTask = Process()
  launchTask.launchPath = "/usr/bin/open"
  launchTask.arguments = ["/System/Applications/Utilities/Terminal.app"]
  launchTask.launch()

  // Step 2: Set position and size of Terminal window
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Small delay to ensure Terminal is open
    // Define main window dimensions
    _ = 800  // Set your main window's width
    _ = 600  // Set your main window's height
    _ = 100  // Approximate height for 5 lines

    let script = """
      tell application "Terminal"
          do script "cd \(directory)"
          activate
          delay 0.5  -- Wait for terminal to become active
      end tell
      """

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    task.launch()
  }
}
