//
//  SMBFileProvider+MountHelpers.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 04.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - SMB Mount Helpers
extension SMBFileProvider {

    static func removeAppMountDirectoryIfEmpty(_ mountPointURL: URL, mountRootURL: URL) {
        guard mountPointURL.path.hasPrefix(mountRootURL.path + "/") else { return }
        let fileManager = FileManager.default
        guard (try? fileManager.contentsOfDirectory(atPath: mountPointURL.path).isEmpty) == true else { return }
        try? fileManager.removeItem(at: mountPointURL)
    }

    // MARK: - URL Encoding
    static func percentEncodedUserInfo(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func percentEncodedHost(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? value
    }
}
