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

    static func install(
        release: GitHubRelease,
        asset: GitHubAsset,
        status: @escaping @Sendable (String) -> Void
    ) async throws {
        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentAppURL.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: currentAppURL.deletingLastPathComponent().path) else {
            throw UpdateInstallerError.installationLocation
        }
        let expectedVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        status("Downloading update...")
        let dmgURL = try await download(asset: asset)
        defer { try? FileManager.default.removeItem(at: dmgURL) }
        status("Verifying download...")
        try verifyDownload(at: dmgURL, asset: asset)
        status("Opening disk image...")
        let mountURL = try await mount(dmgURL)
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mountURL.path, "-quiet"]) }
        let sourceAppURL = mountURL.appendingPathComponent("MiMiNavigator.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceAppURL.path) else {
            throw UpdateInstallerError.invalidApplication
        }
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
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Download
    private static func download(asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadURL) else {
            throw UpdateInstallerError.invalidDownload
        }
        var request = URLRequest(url: url)
        request.setValue("MiMiNavigator-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw UpdateInstallerError.invalidDownload
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dmg")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    // MARK: - Download Verification
    private static func verifyDownload(at url: URL, asset: GitHubAsset) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.intValue == asset.size else {
            throw UpdateInstallerError.invalidDownload
        }
        guard let digest = asset.digest, digest.hasPrefix("sha256:") else { return }
        let expected = String(digest.dropFirst("sha256:".count)).lowercased()
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateInstallerError.invalidDigest }
    }

    // MARK: - Disk Image
    private static func mount(_ dmgURL: URL) async throws -> URL {
        try await Task.detached {
            let output = try run("/usr/bin/hdiutil", ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"])
            guard let plist = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
                  let entities = plist["system-entities"] as? [[String: Any]],
                  let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first else {
                throw UpdateInstallerError.invalidDiskImage
            }
            return URL(fileURLWithPath: mountPath, isDirectory: true)
        }.value
    }

    // MARK: - Application Verification
    private static func verifyApplication(at appURL: URL, expectedVersion: String) throws {
        _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "--verbose=2", appURL.path])
        let details = try run("/usr/bin/codesign", ["-d", "--verbose=4", appURL.path], includeErrorOutput: true)
        let detailText = String(decoding: details, as: UTF8.self)
        guard detailText.contains("TeamIdentifier=\(expectedTeamID)"),
              detailText.contains("Identifier=\(expectedBundleID)") else {
            throw UpdateInstallerError.invalidSignature
        }
        guard let bundle = Bundle(url: appURL),
              bundle.bundleIdentifier == expectedBundleID,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == expectedVersion else {
            throw UpdateInstallerError.invalidVersion
        }
        _ = try run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=2", appURL.path])
    }

    // MARK: - Staging
    private static func stageApplication(from sourceURL: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiNavigatorUpdate-\(UUID().uuidString)", isDirectory: true)
        let stagedURL = directory.appendingPathComponent("MiMiNavigator.app", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try run("/usr/bin/ditto", [sourceURL.path, stagedURL.path])
        return stagedURL
    }

    // MARK: - Replacement Helper
    private static func writeInstallerHelper() throws -> URL {
        let helperURL = FileManager.default.temporaryDirectory.appendingPathComponent("mimi-update-\(UUID().uuidString).zsh")
        let script = """
        #!/bin/zsh
        set -eu
        current="$1"
        staged="$2"
        pid="$3"
        backup="${current}.update-backup"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        rm -rf "$backup"
        mv "$current" "$backup"
        if /usr/bin/ditto "$staged" "$current"; then
            rm -rf "$backup" "${staged:h}"
            /usr/bin/open -n "$current"
            rm -f "$0"
            exit 0
        fi
        rm -rf "$current"
        mv "$backup" "$current"
        /usr/bin/open -n "$current"
        exit 1
        """
        try script.write(to: helperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)
        return helperURL
    }

    private static func launchInstaller(helperURL: URL, stagedAppURL: URL, currentAppURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [helperURL.path, currentAppURL.path, stagedAppURL.path, String(ProcessInfo.processInfo.processIdentifier)]
        try process.run()
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
