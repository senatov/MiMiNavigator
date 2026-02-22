// NetworkAuthService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Refactored: 22.02.2026 — multi-key Keychain search (Finder uses _smb._tcp.local suffix)
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keychain-backed credentials store for network hosts.
//              Saves/loads user+password per hostname using kSecClassInternetPassword.
//              Tries multiple hostname variants to match what Finder stores.

import Foundation
import Security

// MARK: - Credentials for one host
struct NetworkCredentials {
    let user: String
    let password: String
}

// MARK: - Keychain wrapper for network credentials
enum NetworkAuthService {

    // MARK: - Save credentials to Keychain (MiMiNavigator's own entry)
    static func save(_ creds: NetworkCredentials, for host: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassInternetPassword,
            kSecAttrServer:  host,
            kSecAttrAccount: creds.user,
            kSecValueData:   Data(creds.password.utf8),
            kSecAttrLabel:   "MiMiNavigator: \(host)"
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[Auth] saved credentials for \(host) user=\(creds.user)")
        } else {
            log.warning("[Auth] failed to save credentials for \(host): \(status)")
        }
    }

    // MARK: - Load credentials — tries all hostname variants Finder may have stored
    // Finder stores SMB credentials under keys like:
    //   "kira-macpro"                      (plain name)
    //   "kira-macpro.local"                (mDNS)
    //   "kira-macpro._smb._tcp.local"      (Bonjour full)
    //   "kira-macpro.fritz.box"            (DHCP/DNS)
    static func load(for host: String) -> NetworkCredentials? {
        for key in keychainKeys(for: host) {
            if let creds = loadExact(for: key) {
                log.debug("[Auth] found credentials via key='\(key)' user=\(creds.user)")
                return creds
            }
        }
        log.debug("[Auth] no credentials in Keychain for \(host)")
        return nil
    }

    // MARK: - Delete all variants from Keychain
    static func delete(for host: String) {
        for key in keychainKeys(for: host) {
            let query: [CFString: Any] = [
                kSecClass:      kSecClassInternetPassword,
                kSecAttrServer: key
            ]
            SecItemDelete(query as CFDictionary)
        }
        log.info("[Auth] deleted credentials for \(host) (all variants)")
    }

    // MARK: - Build authenticated smb URL
    static func authenticatedURL(host: NetworkHost) -> URL? {
        guard let creds = load(for: host.hostName) else { return host.mountURL }
        var c = URLComponents()
        c.scheme   = host.serviceType == .afp ? "afp" : "smb"
        c.user     = creds.user
        c.password = creds.password
        c.host     = host.hostName
        if host.port != host.serviceType.defaultPort { c.port = host.port }
        c.path = "/"
        return c.url
    }

    // MARK: - Private: exact Keychain lookup
    private static func loadExact(for key: String) -> NetworkCredentials? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassInternetPassword,
            kSecAttrServer:       key,
            kSecReturnAttributes: true,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let dict     = item as? [CFString: Any],
              let account  = dict[kSecAttrAccount] as? String,
              !account.isEmpty,
              account != "No user account",
              let data     = dict[kSecValueData] as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.isEmpty
        else { return nil }
        return NetworkCredentials(user: account, password: password)
    }

    // MARK: - Private: all Keychain key variants for a hostname
    private static func keychainKeys(for host: String) -> [String] {
        // Strip known suffixes to get base name
        var base = host
        for suffix in ["._smb._tcp.local", "._afp._tcp.local", ".local.", ".local", ".fritz.box"] {
            if base.hasSuffix(suffix) {
                base = String(base.dropLast(suffix.count))
                break
            }
        }
        // Build all variants
        var keys: [String] = [
            host,                               // original as-is
            base,                               // plain name e.g. "kira-macpro"
            "\(base).local",                    // mDNS
            "\(base)._smb._tcp.local",          // Bonjour full (what Finder stores)
            "\(base)._afp._tcp.local",
            "\(base).fritz.box",
        ]
        // Deduplicate while preserving order
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
}
