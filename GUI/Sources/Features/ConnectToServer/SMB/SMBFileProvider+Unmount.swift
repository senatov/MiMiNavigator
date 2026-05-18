//
//  SMBFileProvider+Unmount.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - SMB Unmount Helpers
extension SMBFileProvider {

    // MARK: - Unmount
    static func unmountIfNeeded(_ mountPointURL: URL, mountRootURL: URL) throws {
        guard FileManager.default.fileExists(atPath: mountPointURL.path) else { return }
        let result = try runUnmountCommand(mountPointURL)
        if result.exitCode == 0 || isNotMountedOutput(result.combinedOutput) {
            finishUnmount(mountPointURL, mountRootURL: mountRootURL)
            return
        }
        log.warning("[SMB] umount returned exit=\(result.exitCode) path='\(mountPointURL.path)' output='\(result.combinedOutput)'")
        try runDiskutilUnmountIfNeeded(mountPointURL)
        guard !isMounted(at: mountPointURL) else {
            throw SMBProviderError.commandFailed("SMB unmount failed: \(mountPointURL.path) is still mounted")
        }
        finishUnmount(mountPointURL, mountRootURL: mountRootURL)
    }

    // MARK: - Mount State
    static func isMounted(at mountPointURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: mountPointURL.path) else { return false }
        let result = try? runCommand(
            executable: "/sbin/mount",
            arguments: [],
            redactedArguments: [],
            ignoreNonZeroExitCode: true
        )
        guard let output = result?.stdout, !output.isEmpty else { return false }
        return output.contains(" on \(mountPointURL.path) (smbfs")
    }

    // MARK: - Existing System Mount
    static func existingSystemMountPointURL(shareRootPath: String) throws -> URL? {
        let shareName = shareRootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !shareName.isEmpty else { return nil }
        let decodedShareName = shareName.removingPercentEncoding ?? shareName
        let systemMountURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
            .appendingPathComponent(decodedShareName, isDirectory: true)
        return isMounted(at: systemMountURL) ? systemMountURL : nil
    }

    // MARK: - Commands
    private static func runUnmountCommand(_ mountPointURL: URL) throws -> CommandResult {
        try runCommand(
            executable: "/sbin/umount",
            arguments: [mountPointURL.path],
            redactedArguments: [mountPointURL.path],
            ignoreNonZeroExitCode: true
        )
    }

    private static func runDiskutilUnmountIfNeeded(_ mountPointURL: URL) throws {
        let result = try runCommand(
            executable: "/usr/sbin/diskutil",
            arguments: ["unmount", mountPointURL.path],
            redactedArguments: ["unmount", mountPointURL.path],
            ignoreNonZeroExitCode: true
        )
        if result.exitCode == 0 || isNotMountedOutput(result.combinedOutput) {
            log.debug("[SMB] diskutil unmounted '\(mountPointURL.path)'")
            return
        }
        log.warning("[SMB] diskutil unmount returned exit=\(result.exitCode) path='\(mountPointURL.path)' output='\(result.combinedOutput)'")
    }

    private static func isNotMountedOutput(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("not currently mounted")
            || output.localizedCaseInsensitiveContains("not mounted")
    }

    private static func finishUnmount(_ mountPointURL: URL, mountRootURL: URL) {
        log.debug("[SMB] unmounted '\(mountPointURL.path)'")
        removeAppMountDirectoryIfEmpty(mountPointURL, mountRootURL: mountRootURL)
    }
}
