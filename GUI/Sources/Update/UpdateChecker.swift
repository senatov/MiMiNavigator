// UpdateChecker.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Checks GitHub Releases for app updates.

import AppKit
import Foundation

// MARK: - UpdateChecker
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestRelease: GitHubRelease?
    @Published var updateAvailable: Bool = false
    @Published var isChecking: Bool = false
    @Published var isInstalling: Bool = false
    @Published var installStatus: String?
    @Published var error: String?

    private var apiURL: URL {
        URL(string: "https://miminavi.tech/api/github/release")!
    }
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    private init() {}

    // MARK: - Check for Updates
    func checkForUpdates() async {
        log.info("[Update] check started current=\(currentVersion) url=\(apiURL.absoluteString)")
        isChecking = true
        error = nil
        defer { isChecking = false }
        do {
            var request = URLRequest(url: apiURL)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("MiMiNavigator/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                log.error("[Update] check failed: invalid response")
                return
            }
            log.info("[Update] check response status=\(httpResponse.statusCode) bytes=\(data.count)")
            guard httpResponse.statusCode == 200 else {
                error = "Update service error: \(httpResponse.statusCode)"
                log.warning("[Update] service error status=\(httpResponse.statusCode)")
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestRelease = release
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            updateAvailable = isNewer(latestVersion, than: currentVersion)
            let assets = release.assets.map { "\($0.name):\($0.size)" }.joined(separator: ",")
            log.info("[Update] check decoded tag=\(release.tagName) assets=[\(assets)]")
            log.info("[Update] current=\(currentVersion) latest=\(latestVersion) updateAvailable=\(updateAvailable)")
        } catch {
            self.error = error.localizedDescription
            log.error("[Update] check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Version Comparison
    private func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(latestParts.count, currentParts.count) {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
    
    // MARK: - Download Asset
    var dmgAsset: GitHubAsset? {
        latestRelease?.assets.first { $0.name.hasSuffix(".dmg") }
    }
    
    var zipAsset: GitHubAsset? {
        latestRelease?.assets.first { $0.name.hasSuffix(".zip") }
    }
    
    var downloadAsset: GitHubAsset? {
        dmgAsset ?? zipAsset ?? latestRelease?.assets.first
    }
    
    func openReleasePage() {
        guard let release = latestRelease,
              let url = URL(string: release.htmlURL) else { return }
        NSWorkspace.shared.open(url)
    }
    
    func downloadUpdate() {
        guard let asset = downloadAsset,
              let url = URL(string: asset.browserDownloadURL) else {
            openReleasePage()
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Install Update
    func installUpdate() async {
        guard let release = latestRelease, let asset = dmgAsset else {
            error = "No installable DMG was found"
            log.error("[Update] install requested but no DMG asset is available")
            return
        }
        log.info("[Update] install requested tag=\(release.tagName) asset=\(asset.name) size=\(asset.size) digest=\(asset.digest ?? "nil")")
        isInstalling = true
        installStatus = "Downloading update..."
        error = nil
        do {
            try await UpdateInstaller.install(release: release, asset: asset) { [weak self] status in
                log.info("[Update] status: \(status)")
                Task { @MainActor in self?.installStatus = status }
            }
        } catch {
            self.error = error.localizedDescription
            installStatus = nil
            isInstalling = false
            log.error("[Update] install failed: \(error.localizedDescription)")
        }
    }
}
