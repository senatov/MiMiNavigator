// UpdateInstaller.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Downloads, validates, replaces, and relaunches MiMiNavigator updates.

import AppKit
import CryptoKit
import Foundation

// MARK: - Update Installer Error
private enum UpdateInstallerError: LocalizedError {
    case invalidDownload
    case invalidDigest
    case invalidDiskImage
    case invalidApplication
    case invalidSignature
    case invalidVersion
    case installationLocation

    var errorDescription: String? {
        switch self {
            case .invalidDownload: return "The update download is invalid."
            case .invalidDigest: return "The update checksum does not match the published release."
            case .invalidDiskImage: return "The downloaded disk image could not be mounted."
            case .invalidApplication: return "The disk image does not contain MiMiNavigator.app."
            case .invalidSignature: return "The update is not signed by the expected developer."
            case .invalidVersion: return "The downloaded application version does not match the release."
            case .installationLocation: return "MiMiNavigator must be installed in a writable Applications folder."
        }
    }
}

// MARK: - Update Installer
enum UpdateInstaller {
    private static let expectedTeamID = "G2V9T9AD95"
    private static let expectedBundleID = "Senatov.MiMiNavigator"
    private static let productPageURL = URL(string: "https://miminavi.tech/#download")!
    private static let helperLogURL = URL(fileURLWithPath: "/tmp/MiMiNavigatorUpdateHelper.log")

    // MARK: - Install
    static func install(
        release: GitHubRelease,
        asset: GitHubAsset,
        status: @escaping @Sendable (String) -> Void
    ) async throws {
        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        log.info("[Update] install begin currentVersion=\(currentVersion) targetTag=\(release.tagName) app='\(currentAppURL.path)'")
        guard currentAppURL.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: currentAppURL.deletingLastPathComponent().path) else {
            log.error("[Update] install blocked: app parent is not writable path='\(currentAppURL.path)'")
            throw UpdateInstallerError.installationLocation
        }
        let expectedVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        status("Downloading update...")
        let dmgURL = try await download(asset: asset)
        defer {
            log.info("[Update] removing temporary DMG '\(dmgURL.path)'")
            try? FileManager.default.removeItem(at: dmgURL)
        }
        status("Verifying download...")
        try verifyDownload(at: dmgURL, asset: asset)
        status("Opening disk image...")
        let mountURL = try await mount(dmgURL)
        defer {
            log.info("[Update] detaching mounted DMG '\(mountURL.path)'")
            _ = try? run("/usr/bin/hdiutil", ["detach", mountURL.path, "-quiet"])
        }
        let sourceAppURL = mountURL.appendingPathComponent("MiMiNavigator.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceAppURL.path) else {
            log.error("[Update] mounted DMG has no MiMiNavigator.app at '\(sourceAppURL.path)'")
            throw UpdateInstallerError.invalidApplication
        }
        log.info("[Update] mounted app found at '\(sourceAppURL.path)'")
        status("Verifying application signature...")
        try verifyApplication(at: sourceAppURL, expectedVersion: expectedVersion)
        status("Preparing installation...")
        let stagedAppURL = try stageApplication(from: sourceAppURL)
        let helperURL = try writeInstallerHelper()
        try launchInstaller(helperURL: helperURL, stagedAppURL: stagedAppURL, currentAppURL: currentAppURL)
        NSWorkspace.shared.open(productPageURL)
        status("Restarting MiMiNavigator...")
        log.info("[UpdateInstaller] verified update \(expectedVersion); replacement helper launched")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            log.info("[Update] terminating app so helper can replace bundle")
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Download
    private static func download(asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadURL) else {
            log.error("[Update] invalid asset download URL asset=\(asset.name)")
            throw UpdateInstallerError.invalidDownload
        }
        log.info("[Update] download begin asset=\(asset.name) url=\(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue("MiMiNavigator-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log.error("[Update] download failed status=\(status)")
            throw UpdateInstallerError.invalidDownload
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dmg")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? -1
        log.info("[Update] download complete status=\(response.statusCode) path='\(destination.path)' size=\(size)")
        return destination
    }

    // MARK: - Download Verification
    private static func verifyDownload(at url: URL, asset: GitHubAsset) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.intValue == asset.size else {
            log.error("[Update] download size mismatch expected=\(asset.size) path='\(url.path)'")
            throw UpdateInstallerError.invalidDownload
        }
        log.info("[Update] download size verified bytes=\(fileSize.intValue)")
        guard let digest = asset.digest, digest.hasPrefix("sha256:") else { return }
        let expected = String(digest.dropFirst("sha256:".count)).lowercased()
        log.info("[Update] sha256 verify begin expected=\(expected)")
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            log.error("[Update] sha256 mismatch expected=\(expected) actual=\(actual)")
            throw UpdateInstallerError.invalidDigest
        }
        log.info("[Update] sha256 verified actual=\(actual)")
    }

    // MARK: - Disk Image
    private static func mount(_ dmgURL: URL) async throws -> URL {
        try await Task.detached {
            log.info("[Update] hdiutil attach begin path='\(dmgURL.path)'")
            let output = try run("/usr/bin/hdiutil", ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"])
            guard let plist = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
                  let entities = plist["system-entities"] as? [[String: Any]],
                  let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first else {
                log.error("[Update] hdiutil attach produced no mount point")
                throw UpdateInstallerError.invalidDiskImage
            }
            log.info("[Update] hdiutil attach mounted='\(mountPath)'")
            return URL(fileURLWithPath: mountPath, isDirectory: true)
        }.value
    }

    // MARK: - Application Verification
    private static func verifyApplication(at appURL: URL, expectedVersion: String) throws {
        log.info("[Update] codesign verify begin app='\(appURL.path)'")
        _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "--verbose=2", appURL.path])
        let details = try run("/usr/bin/codesign", ["-d", "--verbose=4", appURL.path], includeErrorOutput: true)
        let detailText = String(decoding: details, as: UTF8.self)
        guard detailText.contains("TeamIdentifier=\(expectedTeamID)"),
              detailText.contains("Identifier=\(expectedBundleID)") else {
            log.error("[Update] signature details mismatch expectedTeam=\(expectedTeamID) expectedBundle=\(expectedBundleID)")
            throw UpdateInstallerError.invalidSignature
        }
        guard let bundle = Bundle(url: appURL),
              bundle.bundleIdentifier == expectedBundleID,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == expectedVersion else {
            let bundleVersion = Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "nil"
            log.error("[Update] bundle metadata mismatch expectedVersion=\(expectedVersion) actualVersion=\(bundleVersion)")
            throw UpdateInstallerError.invalidVersion
        }
        log.info("[Update] bundle metadata verified version=\(expectedVersion)")
        _ = try run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=2", appURL.path])
        log.info("[Update] Gatekeeper assessment passed")
    }

    // MARK: - Staging
    private static func stageApplication(from sourceURL: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiNavigatorUpdate-\(UUID().uuidString)", isDirectory: true)
        let stagedURL = directory.appendingPathComponent("MiMiNavigator.app", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        log.info("[Update] staging app source='\(sourceURL.path)' staged='\(stagedURL.path)'")
        _ = try run("/usr/bin/ditto", [sourceURL.path, stagedURL.path])
        log.info("[Update] staging complete staged='\(stagedURL.path)'")
        return stagedURL
    }

    // MARK: - Replacement Helper
    private static func writeInstallerHelper() throws -> URL {
        let helperURL = FileManager.default.temporaryDirectory.appendingPathComponent("mimi-update-\(UUID().uuidString).zsh")
        let helperLogPath = helperLogURL.path
        let script = """
        #!/bin/zsh
        set -eu
        log_file="\(helperLogPath)"
        log() {
            print -r -- "$(date '+%Y-%m-%d %H:%M:%S') [UpdateHelper] $*" >> "$log_file"
        }
        current="$1"
        staged="$2"
        pid="$3"
        backup="${current}.update-backup"
        log "started current=$current staged=$staged pid=$pid"
        while kill -0 "$pid" 2>/dev/null; do log "waiting for app pid=$pid"; sleep 0.2; done
        log "app exited"
        log "removing old backup=$backup"
        rm -rf "$backup" >> "$log_file" 2>&1
        log "moving current app to backup"
        mv "$current" "$backup" >> "$log_file" 2>&1
        log "copying staged app into place"
        if /usr/bin/ditto "$staged" "$current"; then
            log "ditto succeeded"
            rm -rf "$backup" "${staged:h}" >> "$log_file" 2>&1
            log "opening updated app"
            /usr/bin/open -n "$current" >> "$log_file" 2>&1
            log "helper finished successfully"
            rm -f "$0" >> "$log_file" 2>&1
            exit 0
        fi
        log "ditto failed; restoring backup"
        rm -rf "$current" >> "$log_file" 2>&1
        mv "$backup" "$current" >> "$log_file" 2>&1
        log "opening restored app"
        /usr/bin/open -n "$current" >> "$log_file" 2>&1
        log "helper finished with failure"
        exit 1
        """
        try script.write(to: helperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)
        log.info("[Update] helper written path='\(helperURL.path)' helperLog='\(helperLogPath)'")
        return helperURL
    }

    // MARK: - Launch Helper
    private static func launchInstaller(helperURL: URL, stagedAppURL: URL, currentAppURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [helperURL.path, currentAppURL.path, stagedAppURL.path, String(ProcessInfo.processInfo.processIdentifier)]
        try process.run()
        log.info("[Update] helper launched pid=\(process.processIdentifier) path='\(helperURL.path)'")
    }

    // MARK: - Process
    private static func run(_ executable: String, _ arguments: [String], includeErrorOutput: Bool = false) throws -> Data {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "UpdateInstaller", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(decoding: errorOutput, as: UTF8.self)])
        }
        return includeErrorOutput ? standardOutput + errorOutput : standardOutput
    }
}
