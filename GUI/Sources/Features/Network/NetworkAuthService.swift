// NetworkAuthService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
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

    private static let knownHostSuffixes = [
        "._smb._tcp.local",
        "._afp._tcp.local",
        ".local.",
        ".local",
        ".fritz.box"
    ]

    private static func saveQuery(_ creds: NetworkCredentials, host: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: host,
            kSecAttrAccount: creds.user,
            kSecValueData: Data(creds.password.utf8),
            kSecAttrLabel: "MiMiNavigator: \(host)"
        ]
    }

    private static func deleteQuery(host: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: host
        ]
    }

    private static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func usableHost(_ host: String) -> String? {
        let normalized = normalizedHost(host)
        guard !normalized.isEmpty, normalized != "(nil)" else { return nil }
        return normalized
    }

    private static func saveExact(_ creds: NetworkCredentials, for host: String) -> OSStatus {
        let query = saveQuery(creds, host: host)
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Save credentials to Keychain (MiMiNavigator's own entry)
    static func save(_ creds: NetworkCredentials, for host: String) {
        let normalized = normalizedHost(host)
        let keys = keychainKeys(for: normalized)

        guard !keys.isEmpty else {
            log.warning("[Auth] no usable Keychain keys for \(host)")
            return
        }

        var savedKeys: [String] = []
        var lastError: OSStatus = errSecSuccess

        for key in keys {
            let status = saveExact(creds, for: key)
            if status == errSecSuccess {
                savedKeys.append(key)
            } else {
                lastError = status
                log.warning("[Auth] failed to save credentials for \(key): \(status)")
            }
        }

        if !savedKeys.isEmpty {
            log.info("[Auth] saved credentials for \(normalized) user=\(creds.user)")
            log.debug("[Auth] saved keys=\(savedKeys)")
        } else {
            log.warning("[Auth] failed to save credentials for \(normalized): \(lastError)")
        }
    }

    // MARK: - Load credentials — tries all hostname variants Finder may have stored
    // Finder stores SMB credentials under keys like:
    //   "kira-macpro"                      (plain name)
    //   "kira-macpro.local"                (mDNS)
    //   "kira-macpro._smb._tcp.local"      (Bonjour full)
    //   "kira-macpro.fritz.box"            (DHCP/DNS)
    static func load(for host: String) -> NetworkCredentials? {
        for key in keychainKeys(for: normalizedHost(host)) {
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
        for key in keychainKeys(for: normalizedHost(host)) {
            let query = deleteQuery(host: key)
            SecItemDelete(query as CFDictionary)
        }
        log.info("[Auth] deleted credentials for \(host) (all variants)")
    }

    // MARK: - Build authenticated smb URL
    static func authenticatedURL(host: NetworkHost) -> URL? {
        let lookupHost = usableHost(host.hostName) ?? host.effectiveHostName
        guard let creds = load(for: lookupHost) else { return host.mountURL }
        var c = URLComponents()
        c.scheme = host.serviceType == .afp ? "afp" : "smb"
        c.user = creds.user
        c.password = creds.password
        c.host = host.hostName
        if host.port != host.serviceType.defaultPort {
            c.port = host.port
        }
        c.path = "/"
        return c.url
    }

    static func authenticatedURL(for shareURL: URL) -> URL {
        guard let host = shareURL.host else { return shareURL }
        guard let creds = load(for: host) else { return shareURL }
        guard var components = URLComponents(url: shareURL, resolvingAgainstBaseURL: false) else { return shareURL }

        components.user = creds.user
        components.password = creds.password
        return components.url ?? shareURL
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

    private static func stripKnownSuffix(from host: String) -> String {
        var base = normalizedHost(host)

        for suffix in knownHostSuffixes {
            if base.hasSuffix(suffix) {
                base = String(base.dropLast(suffix.count))
                break
            }
        }

        return base
    }

    // MARK: - Private: all Keychain key variants for a hostname
    private static func keychainKeys(for host: String) -> [String] {
        guard let usableOriginal = usableHost(host) else { return [] }

        let base = stripKnownSuffix(from: usableOriginal)
        let rawKeys: [String?] = [
            usableOriginal,
            usableHost(base),
            usableHost("\(base).local"),
            usableHost("\(base).local."),
            usableHost("\(base)._smb._tcp.local"),
            usableHost("\(base)._afp._tcp.local"),
            usableHost("\(base).fritz.box"),
        ]

        var seen: [String] = []
        var result: [String] = []

        for rawKey in rawKeys {
            guard let key = rawKey else { continue }
            let normalizedKey = normalizedHost(key)
            let lowercasedKey = normalizedKey.lowercased()
            guard !seen.contains(lowercasedKey) else { continue }

            seen.append(lowercasedKey)
            result.append(normalizedKey)
        }

        return result
    }
}
