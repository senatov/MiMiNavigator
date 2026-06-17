// TinyURLTokenStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keychain storage for TinyURL API token.

import Foundation
import Security

// MARK: - TinyURLTokenStore

enum TinyURLTokenStore {
    private static let service = "Senatov.MiMiNavigator.TinyURL"
    private static let account = "api-token"

    // MARK: - Load API Token

    static func loadAPIToken() throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery() as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw TinyURLTokenStoreError.keychain(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Save API Token

    static func saveAPIToken(_ token: String) throws {
        try deleteAPIToken(ignoreMissing: true)
        var query = baseQuery()
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecAttrLabel] = "MiMiNavigator TinyURL API token"
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw TinyURLTokenStoreError.keychain(status) }
    }

    // MARK: - Delete API Token

    static func deleteAPIToken(ignoreMissing: Bool = false) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if ignoreMissing && status == errSecItemNotFound { return }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TinyURLTokenStoreError.keychain(status) }
    }

    // MARK: - Queries

    private static func baseQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    // MARK: - Read Query

    private static func readQuery() -> [CFString: Any] {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }
}

// MARK: - TinyURLTokenStoreError

private enum TinyURLTokenStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "TinyURL Keychain operation failed with status \(status)."
        }
    }
}
