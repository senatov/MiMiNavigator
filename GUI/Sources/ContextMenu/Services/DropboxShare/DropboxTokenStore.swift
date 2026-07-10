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
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery() as CFDictionary, &item)
        if status == errSecItemNotFound {
            return try migrateLegacyRefreshToken()
        }
        guard status == errSecSuccess else { throw DropboxError.keychain(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Save Refresh Token

    static func saveRefreshToken(_ token: String) throws {
        _ = SecItemDelete(baseQuery() as CFDictionary)
        var query = baseQuery()
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrLabel] = "MiMiNavigator Dropbox refresh token"
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw DropboxError.keychain(status) }
        try CloudLinkCredentialsStore.setToken(nil, for: .dropboxRefreshToken)
    }

    // MARK: - Delete Refresh Token

    static func deleteRefreshToken(ignoreMissing _: Bool = false) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DropboxError.keychain(status) }
        try CloudLinkCredentialsStore.setToken(nil, for: .dropboxRefreshToken)
    }

    // MARK: - Legacy Migration

    private static func migrateLegacyRefreshToken() throws -> String? {
        guard let token = try CloudLinkCredentialsStore.token(.dropboxRefreshToken) else { return nil }
        try saveRefreshToken(token)
        log.info("[CloudLink] migrated Dropbox refresh token to Keychain")
        return token
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
