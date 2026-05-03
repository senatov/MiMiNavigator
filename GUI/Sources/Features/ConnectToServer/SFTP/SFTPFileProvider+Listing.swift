//
//   SFTPFileProvider+Listing.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Citadel
import FileModelKit
import Foundation

extension SFTPFileProvider {

    // MARK: - Listing

    @concurrent
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        let sftp = try requireSFTPClient()
        let dirPath = normalizedListingRemotePath(path)
        let entries = try await sftp.listDirectory(atPath: dirPath)

        let components = entries.flatMap(\.components)
        let items = components.compactMap { component -> RemoteFileItem? in
            let name = component.filename
            guard name != ".", name != ".." else { return nil }

            let fullPath = fullRemotePath(name: name, in: dirPath)
            let isDirectory = isDirectoryEntry(component) || component.longname.hasPrefix("d")
            let size = fileSize(from: component)
            let modified = modificationDate(from: component)
            let permissions = permissionString(from: component)

            return RemoteFileItem(
                name: name,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                modified: modified,
                permissions: permissions
            )
        }

        log.debug("[SFTP] listed \(items.count) items at \(dirPath) chunks=\(entries.count) components=\(components.count)")
        return items
    }

    // MARK: - Listing helpers

    private func normalizedListingRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return remoteRootPath }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func fullRemotePath(name: String, in directoryPath: String) -> String {
        let normalizedDirectory = normalizedListingRemotePath(directoryPath)
        return normalizedDirectory == "/"
            ? "/\(name)"
            : normalizedDirectory + "/\(name)"
    }

    private func isDirectoryEntry(_ entry: SFTPPathComponent) -> Bool {
        isDirectoryAttributes(entry.attributes)
    }

    func isDirectoryAttributes(_ attributes: SFTPFileAttributes) -> Bool {
        guard let permissions = attributes.permissions else { return false }
        return (permissions & 0o040000) == 0o040000
    }

    private func fileSize(from entry: SFTPPathComponent) -> Int64 {
        Int64(entry.attributes.size ?? 0)
    }

    private func modificationDate(from entry: SFTPPathComponent) -> Date? {
        entry.attributes.accessModificationTime?.modificationTime
    }

    private func permissionString(from entry: SFTPPathComponent) -> String {
        let attributes = entry.attributes

        guard let rawPermissions = attributes.permissions else {
            return entry.longname.split(separator: " ").first.map(String.init) ?? "---------"
        }

        let isDirectory = isDirectoryAttributes(attributes)
        let prefix = isDirectory ? "d" : "-"

        let permissionBits: [(UInt32, Character)] = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x"),
        ]

        let suffix =
            permissionBits.map { bit, symbol in
                (rawPermissions & bit) != 0 ? String(symbol) : "-"
            }
            .joined()

        return prefix + suffix
    }
}
