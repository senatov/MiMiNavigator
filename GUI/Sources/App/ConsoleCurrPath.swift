//
// ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - non-UI helper to open Console for given dir
final class ConsoleCurrPath {
    @discardableResult
    static func open(in directory: String) -> Bool {
        return openConsoleInDirectory(directory)
    }
}

// MARK: -
@discardableResult
func openConsoleInDirectory(_ directoryStr: String) -> Bool {
    log.debug(#function)
    let S = ScrCnst.self

    let dir = directoryStr.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !dir.isEmpty else {
        log.error("empty dir string")
        return false
    }

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
        log.error("dir not found: \(dir)")
        return false
    }

    let resourceURL = Bundle.main.resourceURL
    let expectedPathInSubdir = resourceURL?.appendingPathComponent("\(S.SUBDIR)/\(S.NAME).\(S.EXT)").path ?? S.ERR0
    let expectedPathInRoot = resourceURL?.appendingPathComponent("\(S.NAME).\(S.EXT)").path ?? S.ERR0

    let scriptURL =
        Bundle.main.url(forResource: S.NAME, withExtension: S.EXT, subdirectory: S.SUBDIR)
        ?? Bundle.main.url(forResource: S.NAME, withExtension: S.EXT)
    guard let scriptURL else {
        log.error("AppleScript not found:\n1) \(expectedPathInSubdir)\n2) \(expectedPathInRoot)")
        return false
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [scriptURL.path, dir]
    task.terminationHandler = { proc in
        log.debug("osascript terminated: \(proc.terminationStatus)")
    }

    do {
        try task.run()
        log.debug("osascript started, pid=\(task.processIdentifier)")
        return true
    } catch {
        log.error("osascript failed: \(String(describing: error))")
        return false
    }
}
