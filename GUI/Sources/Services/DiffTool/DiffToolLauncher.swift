//
//  DiffToolLauncher.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Launches external diff/compare tools (DirEqual, KDiff3, FileMerge, etc.).
//               Extracted from MiMiNavigatorApp.swift.

import AppKit
import FileModelKit

// MARK: - DiffToolLauncher
@MainActor
enum DiffToolLauncher {

    // MARK: - launch
    /// Launch best available diff tool for given left/right paths.
    static func launch(left: String, right: String) {
        log.debug("\(#function) left=\(left) right=\(right)")
        let leftURL = URL(fileURLWithPath: left).standardized
        let rightURL = URL(fileURLWithPath: right).standardized
        var isDir: ObjCBool = false
        let comparingDirs =
            FileManager.default.fileExists(atPath: leftURL.path, isDirectory: &isDir) && isDir.boolValue
        let scope: DiffToolScope = comparingDirs ? .dirsOnly : .filesOnly
        let registry = DiffToolRegistry.shared
        guard let tool = registry.resolveTool(for: scope) else {
            log.warning("[Compare] no tool available for scope=\(scope)")
            offerNoToolInstalled(comparingDirs: comparingDirs)
            return
        }
        log.info("[Compare] using '\(tool.name)' binary=\(tool.resolvedBinary)")
        let args = tool.buildArgs(left: leftURL.path, right: rightURL.path)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool.resolvedBinary)
        task.arguments = args
        do {
            try task.run()
            log.info("[Compare] launched \(tool.name) ✓  args=\(args)")
            let bundlePath = tool.displayPath.hasSuffix(".app") ? tool.displayPath : nil
            waitForAppReady(processName: tool.processName, appPath: bundlePath, frame: NSApp.mainWindow?.frame)
        } catch {
            log.error("[Compare] \(tool.name) failed: \(error.localizedDescription)")
            offerNoToolInstalled(comparingDirs: comparingDirs)
        }
    }

    // MARK: - launchDirEqualViaFinder
    static func launchDirEqualViaFinder(leftPath: String, rightPath: String, frame: NSRect?) {
        log.debug("\(#function) left=\(leftPath) right=\(rightPath)")
        let script = """
            tell application "DirEqual" to activate
            delay 0.5
            tell application "System Events"
                tell process "DirEqual"
                    if (count windows) = 0 then
                        tell application "System Events"
                            keystroke "n" using {command down}
                        end tell
                        delay 0.5
                    end if
                    set value of text field 1 of group 1 of window 1 to \(leftPath.appleScriptQuoted)
                    set value of text field 2 of group 1 of window 1 to \(rightPath.appleScriptQuoted)
                end tell
            end tell
            """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        if let err {
            log.error("[Compare] DirEqual launch: \(err["NSAppleScriptErrorMessage"] ?? err)")
            return
        }
        log.info("[Compare] DirEqual activated, paths set — waiting for ready ✓")
        waitForDirEqualReady(leftPath: leftPath, rightPath: rightPath, frame: frame)
    }

    // MARK: - waitForDirEqualReady
    static func waitForDirEqualReady(leftPath: String, rightPath: String, frame: NSRect?, attempt: Int = 0) {
        let maxAttempts = 12
        let interval = 0.5
        Task.detached(priority: .utility) {
            let checkScript = """
                tell application "System Events"
                    if exists process "DirEqual" then
                        if (count windows of process "DirEqual") > 0 then
                            return value of text field 2 of group 1 of window 1 of process "DirEqual"
                        end if
                    end if
                    return ""
                end tell
                """
            var checkErr: NSDictionary?
            let result = NSAppleScript(source: checkScript)?.executeAndReturnError(&checkErr)
            let currentTF2 = result?.stringValue ?? ""
            guard !currentTF2.isEmpty else {
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                    await MainActor.run {
                        waitForDirEqualReady(leftPath: leftPath, rightPath: rightPath, frame: frame, attempt: attempt + 1)
                    }
                } else {
                    await MainActor.run { log.warning("[Compare] DirEqual window never appeared after \(maxAttempts) attempts") }
                }
                return
            }
            let targetFrame = await MainActor.run { frame ?? NSRect(x: 100, y: 100, width: 1200, height: 800) }
            let screenH = await MainActor.run { NSScreen.main?.frame.height ?? 1080 }
            let wx = Int(targetFrame.origin.x)
            let wy = Int(screenH - targetFrame.origin.y - targetFrame.height)
            let ww = Int(targetFrame.width)
            let wh = Int(targetFrame.height)
            let fixScript = """
                tell application "DirEqual" to activate
                delay 0.15
                tell application "System Events"
                    tell process "DirEqual"
                        click button 1 of toolbar 1 of window 1
                        delay 0.15
                        set position of window 1 to {\(wx), \(wy)}
                        set size of window 1 to {\(ww), \(wh)}
                    end tell
                end tell
                """
            var fixErr: NSDictionary?
            NSAppleScript(source: fixScript)?.executeAndReturnError(&fixErr)
            await MainActor.run {
                if let fixErr { log.warning("[Compare] DirEqual setup: \(fixErr["NSAppleScriptErrorMessage"] ?? fixErr)") }
                else { log.info("[Compare] DirEqual ready after \(attempt) poll(s) — compare started ✓") }
            }
        }
    }

    // MARK: - waitForAppReady
    /// Poll until the GUI process has a window, then activate + reposition.
    /// `processName` is the System Events process name (e.g. "Beyond Compare").
    /// `appPath` is the .app bundle path for `tell application` (e.g. "/Applications/Beyond Compare.app").
    static func waitForAppReady(processName: String, appPath: String? = nil, frame: NSRect?, attempt: Int = 0) {
        log.debug("\(#function) app=\(processName) attempt=\(attempt)")
        let maxAttempts = 12
        let interval = 0.5
        // For `tell application`, use quoted POSIX path if .app is available
        let activateTarget = appPath.map { "\($0.appleScriptQuoted)" } ?? processName.appleScriptQuoted
        Task.detached(priority: .utility) {
            let checkScript = """
                tell application "System Events"
                    if exists process \(processName.appleScriptQuoted) then
                        return (count windows of process \(processName.appleScriptQuoted)) as string
                    end if
                    return "0"
                end tell
                """
            var err: NSDictionary?
            let result = NSAppleScript(source: checkScript)?.executeAndReturnError(&err)
            let windowCount = Int(result?.stringValue ?? "0") ?? 0
            guard windowCount > 0 else {
                guard attempt < maxAttempts else {
                    await MainActor.run { log.warning("[Compare] \(processName) window never appeared") }
                    return
                }
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                await MainActor.run { waitForAppReady(processName: processName, appPath: appPath, frame: frame, attempt: attempt + 1) }
                return
            }
            let f = await MainActor.run { frame ?? NSRect(x: 100, y: 100, width: 1200, height: 800) }
            let screenH = await MainActor.run { NSScreen.main?.frame.height ?? 1080 }
            let wx = Int(f.origin.x); let wy = Int(screenH - f.origin.y - f.height)
            let ww = Int(f.width);    let wh = Int(f.height)
            let posScript = """
                tell application \(activateTarget) to activate
                delay 0.2
                tell application "System Events"
                    tell process \(processName.appleScriptQuoted)
                        set position of window 1 to {\(wx), \(wy)}
                        set size of window 1 to {\(ww), \(wh)}
                    end tell
                end tell
                """
            var posErr: NSDictionary?
            NSAppleScript(source: posScript)?.executeAndReturnError(&posErr)
            await MainActor.run {
                if let posErr { log.warning("[Compare] \(processName) position: \(posErr["NSAppleScriptErrorMessage"] ?? posErr)") }
                else { log.info("[Compare] \(processName) ready after \(attempt) poll(s), positioned ✓") }
            }
        }
    }

    // MARK: - offerNoToolInstalled
    @MainActor
    static func offerNoToolInstalled(comparingDirs: Bool) {
        let alert = NSAlert()
        alert.messageText = comparingDirs ? "No Directory Diff Tool Found" : "No File Diff Tool Found"
        alert.informativeText = """
            No suitable diff tool is installed or enabled.

            Recommended free options:
            • KDiff3  —  brew install --cask kdiff3
            • Beyond Compare  —  scootersoftware.com
            • Kaleidoscope  —  App Store

            Configure tools in Settings (⌘,) → Diff Tool.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsCoordinator.shared.toggle()
        }
    }

    // MARK: - offerInstallKDiff3
    @MainActor
    static func offerInstallKDiff3() {
        log.debug("\(#function)")
        let alert = NSAlert()
        alert.messageText = "KDiff3 Not Found"
        alert.informativeText = """
            KDiff3 is a free tool for file and directory comparison.

            Install via Homebrew:
              brew install --cask kdiff3
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install via brew")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let script = """
                tell application "Terminal"
                    activate
                    do script "brew install --cask kdiff3 && echo 'KDiff3 ready'"
                end tell
                """
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            log.info("[Compare] offered KDiff3 install via brew")
        }
    }

    // MARK: - offerInstallXcode
    @MainActor
    static func offerInstallXcode() {
        log.debug("\(#function)")
        let alert = NSAlert()
        alert.messageText = "FileMerge Not Found"
        alert.informativeText =
            "FileMerge is bundled with Xcode and works great for comparing files and folders.\n\nWould you like to install Xcode from the App Store?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open App Store")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id497799835")!)
        }
        log.info("[Compare] offered Xcode via App Store")
    }

}
