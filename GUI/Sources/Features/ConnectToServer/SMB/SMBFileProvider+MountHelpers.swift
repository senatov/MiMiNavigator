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
        try? FileManager.default.removeItem(at: mountPointURL)
    }

    static func sanitizeMountName(_ name: String) -> String {
        var result = name.precomposedStringWithCanonicalMapping
        result = result.replacingOccurrences(of: " ", with: "-")
        result = result.replacingOccurrences(of: "\u{2018}", with: "")
        result = result.replacingOccurrences(of: "\u{2019}", with: "")
        result = result.replacingOccurrences(of: "'", with: "")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        result = result.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        return result.isEmpty ? "share" : result
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
