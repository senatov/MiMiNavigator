//
//  DiffToolLauncher.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Launches external diff/compare tools (DirEqual, DiffMerge, FileMerge, etc.).
//               Priority: DirEqual → FileMerge (opendiff) → kdiff3 → Beyond Compare.
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
        if tool.id == "diffmerge" {
            removeQuarantine(atPath: tool.appPath)
            applyDiffMergeConfigIfNeeded()
        }
        let args = tool.buildArgs(left: leftURL.path, right: rightURL.path)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool.resolvedBinary)
        task.arguments = args
        do {
            try task.run()
            log.info("[Compare] launched \(tool.name) ✓  args=\(args)")
            let bundlePath = tool.appPath.hasSuffix(".app") ? tool.appPath : nil
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
            • DiffMerge  —  brew install --cask diffmerge
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

    // MARK: - offerInstallDiffMerge
    @MainActor
    static func offerInstallDiffMerge() {
        log.debug("\(#function)")
        let alert = NSAlert()
        alert.messageText = "DiffMerge Not Found"
        alert.informativeText = """
            DiffMerge is a free tool for two-panel directory comparison.

            Install via Homebrew:
              brew install --cask diffmerge

            Note: after installation macOS may block the app due to quarantine.
            MiMiNavigator removes quarantine attributes automatically on first launch.
            If you still see a warning, run manually:
              xattr -cr /Applications/DiffMerge.app
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install via brew")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let script = """
                tell application "Terminal"
                    activate
                    do script "brew install --cask diffmerge && (xattr -cr /Applications/DiffMerge.app 2>/dev/null || xattr -cr ~/Applications/DiffMerge.app 2>/dev/null) && echo 'DiffMerge ready ✓'"
                end tell
                """
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            log.info("[Compare] offered DiffMerge install via brew")
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

    // MARK: - removeQuarantine
    static func removeQuarantine(atPath path: String) {
        log.debug("\(#function) path=\(path)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-cr", path]
        do {
            try task.run()
            task.waitUntilExit()
            log.info("[Compare] xattr -cr \(path) ✓")
        } catch {
            log.warning("[Compare] xattr failed: \(error.localizedDescription)")
        }
    }

    // MARK: - applyDiffMergeConfigIfNeeded
    static func applyDiffMergeConfigIfNeeded() {
        log.debug("\(#function)")
        let prefPath = NSHomeDirectory() + "/Library/Preferences/SourceGear DiffMerge Preferences"
        let existing = (try? String(contentsOfFile: prefPath, encoding: .utf8)) ?? ""
        guard !existing.contains("[Folder/Color/Different]") else {
            log.debug("[DiffMerge] config already applied, skipping")
            return
        }
        do {
            try diffMergeDefaultConfig.write(toFile: prefPath, atomically: true, encoding: .utf8)
            log.info("[DiffMerge] default config written to \(prefPath) ✓")
        } catch {
            log.error("[DiffMerge] failed to write config: \(error.localizedDescription)")
        }
    }

    // MARK: - diffMergeDefaultConfig
    // Bundled DiffMerge preferences exported from developer's configured instance
    static let diffMergeDefaultConfig = """
        [Window]
        [Window/Size]
        [Window/Size/Blank]
        w=1358
        h=1059
        maximized=0
        [Window/Size/Folder]
        w=1358
        h=1059
        maximized=0
        [Revision]
        Check=1771462638
        [Folder]
        ShowFlags=31
        [Folder/Printer]
        Font=14:70:SF Pro Display
        [Folder/Color]
        [Folder/Color/Different]
        bg=16242133
        [License]
        Check=1771463713
        [File]
        Font=14:70:SF Pro Display
        [File/Ruleset]
        Serialized=004207024cffffffff0353090000005f44656661756c745f0453010000002a054200064c00000000174c00000000184c00000000154201124c0e000000134c10000000164c18000000144cffffffff024c0000000003530f000000432f432b2b2f432320536f7572636504530a00000063206370702063732068054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d53030000002f5c2a0e53030000005c2a2f0f4200104200114c000000000b4c010000000c4c110000000d53020000002f2f0e53000000000f425c104201114c010000000b4c020000000c4c0e0000000d5301000000220e5301000000220f425c104201114c020000000b4c030000000c4c0e0000000d5301000000270e5301000000270f425c104201114c03000000124c18000000134c10000000164c18000000144c00000000024c0100000003531300000056697375616c20426173696320536f757263650453170000006261732066726d20636c73207662702063746c20766273054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d5301000000270e53000000000f4200104201114c000000000b4c010000000c4c0e0000000d5301000000220e5301000000220f4200104200114c01000000124c10000000134c10000000164c10000000144c01000000024c0200000003530d000000507974686f6e20536f757263650453020000007079054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d5301000000230e53000000000f4200104201114c000000000b4c010000000c4c0e0000000d5301000000220e5301000000220f4200104200114c01000000124c0c000000134c10000000164c18000000144c02000000024c0300000003530b0000004a61766120536f757263650453080000006a617661206a6176054203064c01000000174c01000000184c010000001542010b4c000000000c4c110000000d53030000002f5c2a0e53030000005c2a2f0f4200104200114c000000000b4c010000000c4c110000000d53020000002f2f0e53000000000f425c104201114c010000000b4c020000000c4c0e0000000d5301000000220e5301000000220f425c104201114c02000000124c18000000134c10000000164c18000000144c03000000024c0400000003530a000000546578742046696c65730453080000007478742074657874054203064c01000000174c01000000184c01000000154201124c0e000000134c10000000164c18000000144c04000000024c050000000353100000005554462d3820546578742046696c65730453080000007574662075746638054203064c2b000000174c2b000000184c2b000000154201124c0e000000134c10000000164c18000000144c05000000024c06000000035309000000584d4c2046696c6573045303000000786d6c054203064c2b000000174c2b000000184c2b0000001542010b4c000000000c4c110000000d53040000003c212d2d0e53030000002d2d3e0f4200104200114c00000000124c18000000134c10000000164c18000000144c06000000014207
        [File/Printer]
        Font=14:70:SF Pro Display
        [ExternalTools]
        Serialized=004201014201
        [Options]
        [Dialog]
        [Dialog/Color]
        CustomColors=::::::::::::::::
        [Misc]
        CheckFoldersOnActivate=1
        """
}
