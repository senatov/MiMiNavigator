// ArchivePasswordStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Storage for archive default password.
//   Debug builds keep the password only in memory for the current session.
//   Non-Debug builds store the password in Keychain.
//   One global password is used for all encrypted archive formats (ZIP, 7z, RAR).
//   On open: tries saved password first, prompts user if it fails.

import Foundation
import Security

@MainActor
final class ArchivePasswordStore {
    static let shared = ArchivePasswordStore()

    #if DEBUG
    private var sessionPassword: String?
    #endif

    private let service = "com.senatov.MiMiNavigator.archive"
    private let account = "default-archive-password"

    private init() {}

    // MARK: - Save
    func savePassword(_ password: String) {
        deletePassword()
        guard !password.isEmpty else { return }

        #if DEBUG
        sessionPassword = password
        log.info("[ArchivePassword] saved for current Debug session only")
        #else
        savePasswordToKeychain(password)
        #endif
    }

    // MARK: - Load
    func loadPassword() -> String? {
        #if DEBUG
        sessionPassword
        #else
        loadPasswordFromKeychain()
        #endif
    }

    // MARK: - Delete
    func deletePassword() {
        #if DEBUG
        sessionPassword = nil
        log.debug("[ArchivePassword] deleted from Debug session store")
        #else
        deletePasswordFromKeychain()
        #endif
    }

    #if !DEBUG
    // MARK: - Keychain
    private func savePasswordToKeychain(_ password: String) {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[ArchivePassword] saved to Keychain")
        } else {
            log.warning("[ArchivePassword] save failed: \(status)")
        }
    }

    private func loadPasswordFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deletePasswordFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
        log.debug("[ArchivePassword] deleted from Keychain")
    }
    #endif
}
