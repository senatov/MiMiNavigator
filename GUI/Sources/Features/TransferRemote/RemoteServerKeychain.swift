// RemoteServerKeychain.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Credential helpers for remote server passwords.
//   Debug builds keep passwords only in memory for the current session.
//   Non-Debug builds store passwords in Keychain.

import Foundation
import Security

// MARK: - RemoteServerKeychain

enum RemoteServerKeychain {
    #if DEBUG
    @MainActor
    private static var sessionPasswords: [String: String] = [:]
    #endif

    private static func passwordKey(for server: RemoteServer) -> String {
        "\(server.remoteProtocol.rawValue)|\(server.host)|\(server.port)|\(server.user)"
    }

    private static func keychainLabel(for server: RemoteServer) -> String {
        "MiMiNavigator-Remote: \(server.host):\(server.port)"
    }

    static func savePassword(_ password: String, for server: RemoteServer) {
        guard !password.isEmpty else { return }

        #if DEBUG
        Task { @MainActor in
            sessionPasswords[passwordKey(for: server)] = password
            log.info("[PasswordStore] saved session-only password for \(server.host):\(server.port)")
        }
        #else
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecValueData: Data(password.utf8),
            kSecAttrLabel: keychainLabel(for: server),
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[Keychain] saved pwd for \(server.host):\(server.port)")
        } else {
            log.warning("[Keychain] save failed: \(status)")
        }
        #endif
    }

    static func loadPassword(for server: RemoteServer) -> String {
        #if DEBUG
        let key = passwordKey(for: server)
        let host = server.host
        let port = server.port

        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                sessionPasswords[key] ?? ""
            }
        }

        log.debug("[PasswordStore] loadPassword requested off main thread in DEBUG for \(host):\(port)")
        return ""
        #else
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return password
        #endif
    }

    static func deletePassword(for server: RemoteServer) {
        #if DEBUG
        Task { @MainActor in
            sessionPasswords.removeValue(forKey: passwordKey(for: server))
        }
        #else
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server.host,
            kSecAttrPort: server.port,
            kSecAttrAccount: server.user,
        ]

        SecItemDelete(query as CFDictionary)
        #endif
    }

    private static func protocolAttr(_ proto: RemoteProtocol) -> CFString {
        switch proto {
        case .sftp:
            return kSecAttrProtocolSSH
        case .ftp:
            return kSecAttrProtocolFTP
        case .smb:
            return kSecAttrProtocolSMB
        case .afp:
            return kSecAttrProtocolAFP
        }
    }
}
