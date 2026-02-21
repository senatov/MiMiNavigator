// NetworkAuthService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keychain-backed credentials store for network hosts.
//              Saves/loads user+password per hostname using kSecClassInternetPassword.

import Foundation
import Security

// MARK: - Credentials for one host
struct NetworkCredentials {
    let user: String
    let password: String
}

// MARK: - Keychain wrapper for network credentials
enum NetworkAuthService {

    // MARK: - Save credentials to Keychain
    static func save(_ creds: NetworkCredentials, for host: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassInternetPassword,
            kSecAttrServer:  host,
            kSecAttrAccount: creds.user,
            kSecValueData:   Data(creds.password.utf8),
            kSecAttrLabel:   "MiMiNavigator: \(host)"
        ]
        // Delete old entry first (update not supported simply)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[Auth] saved credentials for \(host) user=\(creds.user)")
        } else {
            log.warning("[Auth] failed to save credentials for \(host): \(status)")
        }
    }

    // MARK: - Load credentials from Keychain
    static func load(for host: String) -> NetworkCredentials? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassInternetPassword,
            kSecAttrServer:       host,
            kSecReturnAttributes: true,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let dict = item as? [CFString: Any],
              let account = dict[kSecAttrAccount] as? String,
              let data = dict[kSecValueData] as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            log.debug("[Auth] no credentials in Keychain for \(host)")
            return nil
        }
        log.debug("[Auth] loaded credentials for \(host) user=\(account)")
        return NetworkCredentials(user: account, password: password)
    }

    // MARK: - Delete credentials from Keychain
    static func delete(for host: String) {
        let query: [CFString: Any] = [
            kSecClass:      kSecClassInternetPassword,
            kSecAttrServer: host
        ]
        let status = SecItemDelete(query as CFDictionary)
        log.info("[Auth] deleted credentials for \(host) status=\(status)")
    }

    // MARK: - Build authenticated smb URL
    static func authenticatedURL(host: NetworkHost) -> URL? {
        guard let creds = load(for: host.hostName) else { return host.mountURL }
        var c = URLComponents()
        c.scheme = host.serviceType == .afp ? "afp" : "smb"
        c.user = creds.user
        c.password = creds.password
        c.host = host.hostName
        if host.port != host.serviceType.defaultPort { c.port = host.port }
        c.path = "/"
        return c.url
    }
}
