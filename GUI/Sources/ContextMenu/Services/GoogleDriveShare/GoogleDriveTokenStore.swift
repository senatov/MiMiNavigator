// GoogleDriveTokenStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keychain storage for Google Drive OAuth refresh token.

import Foundation
import Security

// MARK: - GoogleDriveTokenStore

enum GoogleDriveTokenStore {
    private static let service = "Senatov.MiMiNavigator.GoogleDrive"
    private static let refreshAccount = "refresh-token"

    // MARK: - Load Refresh Token

    static func loadRefreshToken() throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery() as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw GoogleDriveError.keychain(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Save Refresh Token

    static func saveRefreshToken(_ token: String) throws {
        try deleteRefreshToken(ignoreMissing: true)
        var query = baseQuery()
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrLabel] = "MiMiNavigator Google Drive refresh token"
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw GoogleDriveError.keychain(status) }
    }

    // MARK: - Delete Refresh Token

    static func deleteRefreshToken(ignoreMissing: Bool = false) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if ignoreMissing && status == errSecItemNotFound { return }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw GoogleDriveError.keychain(status) }
    }

    // MARK: - Queries

    private static func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: refreshAccount,
        ]
    }

    // MARK: - Read Query

    private static func readQuery() -> [CFString: Any] {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }
}
