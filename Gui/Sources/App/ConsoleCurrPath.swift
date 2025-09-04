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

// MARK: - ScriptConstants

private enum ScrCnst {
    static let NAME = "OpenTerminal"
    static let EXT = "scpt"
    static let SUBDIR = "Gui/OSScript"
    static let ERR0 = "(unknown bundle resourceURL)"
}

// MARK: - ConsoleCurrPath
struct ConsoleCurrPath: View {
    var body: some View {
        VStack {}
            .foregroundColor(.primary) // System default color
            .padding()
            .onAppear {
                // Log only once when view appears to avoid side effects in body
                log.info("ConsoleCurrPath appeared")
            }
    }
}

// MARK: - -
func openConsoleInDirectory(_ directoryStr: String) {
    log.info(#function)
    // Prefer scripts located under Gui/OSScript inside the app bundle
    let resourceURL = Bundle.main.resourceURL
    let expectedPathInSubdir = resourceURL?.appendingPathComponent("\(ScrCnst.SUBDIR)/\(ScrCnst.NAME).\(ScrCnst.EXT)").path ?? ScrCnst.ERR0
    let expectedPathInRoot = resourceURL?.appendingPathComponent("\(ScrCnst.NAME).\(ScrCnst.EXT)").path ?? ScrCnst.ERR0
    // Try subdirectory first
    let scriptURL = Bundle.main.url(forResource: ScrCnst.NAME, withExtension: ScrCnst.EXT, subdirectory: ScrCnst.SUBDIR)
        ?? Bundle.main.url(forResource: ScrCnst.NAME, withExtension: ScrCnst.EXT)
    guard let scriptURL else {
        log.error("AppleScript file not found. Looked in: \n1) \(expectedPathInSubdir) \n2) \(expectedPathInRoot)")
        return
    }
    // Run AppleScript via osascript, passing the target directory as a single argv parameter.
    // The AppleScript should handle it via: `on run argv` and use item 1 as the POSIX path.
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [scriptURL.path, directoryStr]

    do {
        try task.run()
    } catch {
        log.error("osascript run failed: \(String(describing: error))")
    }
}
