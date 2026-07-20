// UpdateAssetIdentity.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persists the exact GitHub release asset installed by the updater.

import Foundation

// MARK: - Installed Update Identity
struct InstalledUpdateIdentity: Codable, Equatable, Sendable {
    let version: String
    let assetFingerprint: String
    let buildStamp: String
}

// MARK: - Update Asset Identity Store
@MainActor
enum UpdateAssetIdentityStore {
    private static let installedKey = "Update.installedAssetIdentity.v1"
    private static let pendingKey = "Update.pendingAssetIdentity.v1"
    static let initialReleaseUploadTolerance: TimeInterval = 10 * 60
    static func assetFingerprint(_ asset: GitHubAsset) -> String {
        if let digest = asset.digest?.lowercased(), !digest.isEmpty { return digest }
        return "id:\(asset.id.map(String.init) ?? "nil")|updated:\(asset.updatedAt ?? "nil")|size:\(asset.size)"
    }
    static func installedIdentity() -> InstalledUpdateIdentity? {
        decode(forKey: installedKey)
    }
    static func stageInstallation(release: GitHubRelease, asset: GitHubAsset, appURL: URL) {
        let identity = InstalledUpdateIdentity(
            version: release.normalizedVersion,
            assetFingerprint: assetFingerprint(asset),
            buildStamp: buildStamp(in: Bundle(url: appURL)) ?? ""
        )
        save(identity, forKey: pendingKey)
        MiMiDefaults.shared.synchronize()
        log.info("[Update] staged asset identity version=\(identity.version) fingerprint='\(identity.assetFingerprint)' buildStamp='\(identity.buildStamp)'")
    }
    static func reconcilePendingInstallation(currentVersion: String, bundle: Bundle = .main) {
        guard let pending: InstalledUpdateIdentity = decode(forKey: pendingKey) else { return }
        let localStamp = buildStamp(in: bundle) ?? ""
        guard pending.version == currentVersion, !pending.buildStamp.isEmpty, pending.buildStamp == localStamp else {
            log.warning("[Update] pending asset identity does not match current app; keeping it pending")
            return
        }
        save(pending, forKey: installedKey)
        MiMiDefaults.shared.removeObject(forKey: pendingKey)
        MiMiDefaults.shared.synchronize()
        log.info("[Update] installed asset identity confirmed fingerprint='\(pending.assetFingerprint)'")
    }
    static func localBuildDate(bundle: Bundle = .main) -> Date? {
        guard let stamp = buildStamp(in: bundle) else { return nil }
        let prefix = String(stamp.prefix(19))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return formatter.date(from: prefix)
    }
    private static func buildStamp(in bundle: Bundle?) -> String? {
        guard let url = bundle?.url(forResource: "curr_version", withExtension: "asc") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func save(_ identity: InstalledUpdateIdentity, forKey key: String) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        MiMiDefaults.shared.set(data, forKey: key)
    }
    private static func decode(forKey key: String) -> InstalledUpdateIdentity? {
        guard let data = MiMiDefaults.shared.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InstalledUpdateIdentity.self, from: data)
    }
}
