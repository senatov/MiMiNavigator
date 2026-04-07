//
//  RemoteSrKeyChain+Pwd.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import LocalAuthentication
import Security

extension RemoteServerKeychain {

    static func savePassword(_ password: String, for server: RemoteServer) {
        guard !password.isEmpty else {
            log.warning("[Keychain] save skipped for \(endpointDescription(for: server)) because password is empty")
            return
        }

        bootstrapPasswordIndexFileIfNeeded()

        let query = passwordWriteQuery(password, for: server)
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logKeychainFailure("delete-before-save", status: deleteStatus, server: server)
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info(
                "[Keychain] saved password for \(endpointDescription(for: server)) accessibility=afterFirstUnlock noUserPresence=true"
            )
            cachePassword(password, for: server)
            updatePasswordIndex(for: server, hasPassword: true)
            return
        }

        logKeychainFailure("save", status: status, server: server)
        updatePasswordIndex(for: server, hasPassword: false, lastError: "save failed: \(statusDescription(status))")
    }

    static func loadPassword(for server: RemoteServer) -> String {
        bootstrapPasswordIndexFileIfNeeded()

        if let cachedPassword = cachedPassword(for: server) {
            log.debug("[Keychain] loaded password from runtime cache for \(endpointDescription(for: server))")
            return cachedPassword
        }

        logPasswordIndexState(for: server)

        let query = passwordReadQuery(for: server)
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            handleLoadFailure(status, for: server)
            return ""
        }

        guard let data = item as? Data else {
            log.error("[Keychain] load returned unexpected payload for \(endpointDescription(for: server))")
            updatePasswordIndex(for: server, hasPassword: false, lastError: "unexpected payload")
            return ""
        }

        guard let password = String(data: data, encoding: .utf8) else {
            log.error("[Keychain] load returned non-UTF8 password data for \(endpointDescription(for: server))")
            updatePasswordIndex(for: server, hasPassword: false, lastError: "non-UTF8 payload")
            return ""
        }

        cachePassword(password, for: server)
        updatePasswordIndex(for: server, hasPassword: true, lastLoadAt: Date())
        log.debug(
            "[Keychain] loaded password for \(endpointDescription(for: server)) interactionNotAllowed=true accessibility=afterFirstUnlock"
        )
        return password
    }

    static func deletePassword(for server: RemoteServer) {
        bootstrapPasswordIndexFileIfNeeded()

        let query = passwordDeleteQuery(for: server)
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            log.info("[Keychain] deleted password for \(endpointDescription(for: server))")
            removeCachedPassword(for: server)
            removePasswordIndex(for: server)
            return
        }

        if status == errSecItemNotFound {
            log.info("[Keychain] delete skipped, no saved password for \(endpointDescription(for: server))")
            removeCachedPassword(for: server)
            removePasswordIndex(for: server)
            return
        }

        logKeychainFailure("delete", status: status, server: server)
        updatePasswordIndex(for: server, hasPassword: false, lastError: "delete failed: \(statusDescription(status))")
    }
}
