//
//  ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
//  Description: Minimal view + helper to open Console for a given directory.
//  Notes: Comments in English only. Logging via SwiftBeaver.
//

import SwiftUI

// MARK: - ConsoleCurrPath
struct ConsoleCurrPath: View {
    var body: some View {
        // Render nothing; this view acts as a lifecycle hook only
        Color.clear
            .onAppear {
                // Log once when the view appears to avoid side effects inside body computation
                log.debug("ConsoleCurrPath appeared")
            }
    }
}

// MARK: - Open Console Helper
@discardableResult
func openConsoleInDirectory(_ directoryStr: String) -> Bool {
    log.debug(#function)
    let S = ScrCnst.self
    // Validate directory string
    let dir = directoryStr.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !dir.isEmpty else {
        log.error("Empty directory string passed to openConsoleInDirectory")
        return false
    }
    // Ensure path exists and is a directory
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
        log.error("Directory not found or not a directory: \(dir)")
        return false
    }
    // Prefer scripts located under Gui/OSScript inside the app bundle
    let resourceURL = Bundle.main.resourceURL
    let expectedPathInSubdir = resourceURL?.appendingPathComponent("\(S.SUBDIR)/\(S.NAME).\(S.EXT)").path ?? S.ERR0
    let expectedPathInRoot = resourceURL?.appendingPathComponent("\(S.NAME).\(S.EXT)").path ?? S.ERR0
    // Try subdirectory first; then bundle root
    let scriptURL =
        Bundle.main.url(forResource: S.NAME, withExtension: S.EXT, subdirectory: S.SUBDIR)
        ?? Bundle.main.url(forResource: S.NAME, withExtension: S.EXT)
    guard let scriptURL else {
        log.error("AppleScript file not found. Looked in:\n1) \(expectedPathInSubdir)\n2) \(expectedPathInRoot)")
        return false
    }
    // Run AppleScript via osascript, passing the target directory as a single argv parameter.
    // The AppleScript should handle it via: `on run argv` and use item 1 as the POSIX path.
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [scriptURL.path, dir]
    task.terminationHandler = { proc in
        log.debug("osascript terminated with status: \(proc.terminationStatus)")
    }
    do {
        try task.run()
        log.debug("osascript started, pid=\(task.processIdentifier)")
        return true
    } catch {
        log.error("osascript run failed: \(String(describing: error))")
        return false
    }
}
