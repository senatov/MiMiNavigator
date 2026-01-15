// ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Helper to open Terminal at specified directory
final class ConsoleCurrPath {
    
    @discardableResult
    static func open(in directory: String) -> Bool {
        openTerminalInDirectory(directory)
    }
}

// MARK: - Open Terminal via AppleScript
@discardableResult
private func openTerminalInDirectory(_ directoryStr: String) -> Bool {
    let config = TerminalScriptConfig.self

    let dir = directoryStr.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !dir.isEmpty else {
        log.error("Empty directory string provided")
        return false
    }

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
        log.error("Directory not found: \(dir)")
        return false
    }

    let resourceURL = Bundle.main.resourceURL
    let expectedPathInSubdir = resourceURL?
        .appendingPathComponent("\(config.scriptSubdirectory)/\(config.scriptName).\(config.scriptExtension)")
        .path ?? config.unknownBundleURL
    let expectedPathInRoot = resourceURL?
        .appendingPathComponent("\(config.scriptName).\(config.scriptExtension)")
        .path ?? config.unknownBundleURL

    let scriptURL = Bundle.main.url(
        forResource: config.scriptName,
        withExtension: config.scriptExtension,
        subdirectory: config.scriptSubdirectory
    ) ?? Bundle.main.url(
        forResource: config.scriptName,
        withExtension: config.scriptExtension
    )
    
    guard let scriptURL else {
        log.error("AppleScript not found:\n1) \(expectedPathInSubdir)\n2) \(expectedPathInRoot)")
        return false
    }

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
        log.error("osascript failed: \(error.localizedDescription)")
        return false
    }
}
