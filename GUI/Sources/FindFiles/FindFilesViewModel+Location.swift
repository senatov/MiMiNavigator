// FindFilesViewModel+Location.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: Resolves the search location supplied by the originating panel.

import FileModelKit
import FindFilesKit
import Foundation

// MARK: - Search Location
extension FindFilesViewModel {
    func configure(searchPath: String, selectedFile _: CustomFile? = nil) {
        if let remoteURL = URL(string: searchPath), ["sftp", "ftp", "smb"].contains(remoteURL.scheme?.lowercased() ?? "") {
            searchDirectory = remoteURL.absoluteString
            return
        }
        let path = (searchPath as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        searchDirectory = exists && !isDirectory.boolValue
            ? URL(fileURLWithPath: path).deletingLastPathComponent().path : path
    }

    func localLeftoverRoots(within selectedURL: URL) -> [URL] {
        let selected = selectedURL.standardizedFileURL.path
        return FindFilesLeftoverSafety.searchDirectories.compactMap { root in
            let path = root.standardizedFileURL.path
            if path == selected || path.hasPrefix(selected == "/" ? selected : selected + "/") { return root }
            if selected.hasPrefix(path + "/") { return selectedURL }
            return nil
        }
    }
}
