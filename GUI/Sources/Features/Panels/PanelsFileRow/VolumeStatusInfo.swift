// VolumeStatusInfo.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact mounted volume capacity and filesystem labels.

import Foundation

// MARK: - Volume Status Info
enum VolumeStatusInfo {

    // MARK: - Capacity
    struct Capacity {
        let label: String
        let systemImage: String
    }

    // MARK: - Capacity Label
    static func capacityLabel(for url: URL) -> String? {
        capacity(for: url)?.label
    }

    // MARK: - Capacity Info
    static func capacity(for url: URL) -> Capacity? {
        guard let volumeURL = mountedVolumeRoot(for: url) else { return nil }
        guard let free = availableCapacity(for: volumeURL) else { return nil }
        let freeText = formatBytes(free)
        let totalText = totalCapacity(for: volumeURL).map(formatBytes)
        let formatText = filesystemFormat(for: volumeURL)
        let label = [freeText, totalText].compactMap { $0 }.joined(separator: " / ")
            + formatText.map { ", \($0)" }.orEmpty
        return Capacity(label: label, systemImage: deviceSymbol(for: volumeURL))
    }

    // MARK: - Mounted Volume Root
    static func mountedVolumeRoot(for url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        if let volumeURL = resourceVolumeURL(for: url), AppState.isMountedVolumeRootPath(volumeURL.path) {
            return volumeURL
        }
        return derivedMountedVolumeRoot(for: url)
    }

    // MARK: - Resource Volume URL
    private static func resourceVolumeURL(for url: URL) -> URL? {
        var value: AnyObject?
        guard (try? (url as NSURL).getResourceValue(&value, forKey: URLResourceKey.volumeURLKey)) != nil else { return nil }
        return value as? URL
    }

    // MARK: - Available Capacity
    static func availableCapacity(for url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity,
           capacity > 0
        {
            return Int64(capacity)
        }
        return fileSystemCapacity(for: url, key: .systemFreeSize)
    }

    // MARK: - Total Capacity
    static func totalCapacity(for url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]),
           let capacity = values.volumeTotalCapacity,
           capacity > 0
        {
            return Int64(capacity)
        }
        return fileSystemCapacity(for: url, key: .systemSize)
    }

    // MARK: - Filesystem Format
    static func filesystemFormat(for url: URL) -> String? {
        guard
            let values = try? url.resourceValues(forKeys: [.volumeLocalizedFormatDescriptionKey]),
            let raw = values.volumeLocalizedFormatDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        return compactFormatName(raw)
    }

    // MARK: - Device Symbol
    static func deviceSymbol(for url: URL) -> String {
        let keys: Set<URLResourceKey> = [
            .volumeIsEjectableKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeLocalizedNameKey,
            .volumeNameKey,
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let hint = [
            values?.volumeLocalizedName,
            values?.volumeName,
            values?.volumeLocalizedFormatDescription,
            url.lastPathComponent,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        if hint.contains("cd") || hint.contains("dvd") || hint.contains("blu-ray") { return "opticaldiscdrive" }
        if hint.contains("sd") || hint.contains("card") { return "sdcard" }
        if hint.contains("ssd") || hint.contains("flash") { return "externaldrive.fill" }
        if values?.volumeIsInternal == true { return "internaldrive" }
        if values?.volumeIsEjectable == true || values?.volumeIsRemovable == true { return "externaldrive.fill" }
        return "externaldrive"
    }

    // MARK: - File System Capacity
    private static func fileSystemCapacity(for url: URL, key: FileAttributeKey) -> Int64? {
        guard
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
            let number = attrs[key] as? NSNumber,
            number.int64Value > 0
        else {
            return nil
        }
        return number.int64Value
    }

    // MARK: - Format Bytes
    private static func formatBytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    // MARK: - Compact Format Name
    private static func compactFormatName(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("ntfs") { return "NTFS" }
        if lower.contains("exfat") { return "ExFAT" }
        if lower.contains("fat32") { return "FAT32" }
        if lower.contains("apfs") { return "APFS" }
        if lower.contains("mac os extended") { return "HFS+" }
        return raw
    }

    // MARK: - Derived Mounted Volume Root
    private static func derivedMountedVolumeRoot(for url: URL) -> URL? {
        let components = NSString(string: url.path).standardizingPath.split(separator: "/")
        guard components.count >= 2, components[0] == "Volumes" else { return nil }
        let volumePath = "/Volumes/" + components[1]
        return URL(fileURLWithPath: volumePath, isDirectory: true)
    }
}

// MARK: - Optional String Glue
private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
