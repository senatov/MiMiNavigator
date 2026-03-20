// ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024-2026 Senatov. All rights reserved.
//  Description: Opens Terminal.app at a specified directory.
//               AppleScript `launch` + `activate` + `do script "cd ..."`.
//               Requires com.apple.Terminal in sandbox apple-events exceptions.

import AppKit
import Foundation

// MARK: - Helper to open Terminal at specified directory
final class ConsoleCurrPath {

    @discardableResult
    static func open(in directory: String) -> Bool {
        let dir = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dir.isEmpty else {
            log.error("[Console] Empty directory string provided")
            return false
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            log.error("[Console] Directory not found: \(dir)")
            return false
        }
        let escapedDir = dir.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // `launch` starts Terminal without bringing it to front (no-op if already running)
        // `activate` brings it to front
        // `do script` executes cd in a new tab/window
        let script = """
            tell application "Terminal"
                launch
                activate
                do script "cd \\\"\(escapedDir)\\\" && clear"
            end tell
            """
        guard let appleScript = NSAppleScript(source: script) else {
            log.error("[Console] Failed to create AppleScript")
            return false
        }
        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        if let error = errorDict {
            log.error("[Console] AppleScript error: \(error)")
            return false
        }
        log.info("[Console] Terminal opened for: \(dir)")
        return true
    }
}
