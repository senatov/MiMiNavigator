// DropboxTokenStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Stores the Dropbox OAuth refresh token locally and in Keychain.

import Foundation
import Security

// MARK: - DropboxTokenStore

enum DropboxTokenStore {
    private static let service = "Senatov.MiMiNavigator.Dropbox"
    private static let account = "refresh-token"

    // MARK: - Load Refresh Token

    static func loadRefreshToken() throws -> String? {
        if let token = try CloudLinkCredentialsStore.token(.dropboxRefreshToken) {
            return token
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery() as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw DropboxError.keychain(status) }
        guard let data = item as? Data else { return nil }
        let token = String(data: data, encoding: .utf8)
        if let token {
            try? CloudLinkCredentialsStore.setToken(token, for: .dropboxRefreshToken)
        }
        return token
    }

    // MARK: - Save Refresh Token

    static func saveRefreshToken(_ token: String) throws {
        try CloudLinkCredentialsStore.setToken(token, for: .dropboxRefreshToken)
        _ = SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrLabel] = "MiMiNavigator Dropbox refresh token"
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            log.warning("[CloudLink] Dropbox Keychain mirror save failed status=\(status)")
        }
    }

    // MARK: - Delete Refresh Token

    static func deleteRefreshToken(ignoreMissing: Bool = false) throws {
        try CloudLinkCredentialsStore.setToken(nil, for: .dropboxRefreshToken)
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if ignoreMissing && status == errSecItemNotFound { return }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DropboxError.keychain(status) }
    }

    // MARK: - Queries

    private static func baseQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    private static func readQuery() -> [CFString: Any] {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }
}
