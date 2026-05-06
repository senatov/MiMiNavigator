// VolumeStatusInfo.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact mounted volume capacity and filesystem labels.

import Foundation

// MARK: - Volume Status Info
enum VolumeStatusInfo {

    // MARK: - Capacity Label
    static func capacityLabel(for url: URL) -> String? {
        guard AppState.isMountedVolumeRootPath(url.path) else { return nil }
        guard let free = availableCapacity(for: url) else { return nil }
        let freeText = formatBytes(free)
        let totalText = totalCapacity(for: url).map(formatBytes)
        let formatText = filesystemFormat(for: url)
        return [freeText, totalText].compactMap { $0 }.joined(separator: " / ")
            + formatText.map { ", \($0)" }.orEmpty
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
}

// MARK: - Optional String Glue
private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
