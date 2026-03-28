// RemoteServerKeychain.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keychain helpers for remote server passwords.
//   Extracted from RemoteServerStore.swift for single responsibility.

import Foundation
import Security


// MARK: - RemoteServerKeychain

enum RemoteServerKeychain {

    private static func keychainLabel(for server: RemoteServer) -> String {
        "MiMiNavigator-Remote: \(server.host):\(server.port)"
    }



    static func savePassword(_ password: String, for server: RemoteServer) {
        guard !password.isEmpty else { return }
        let query: [CFString: Any] = [
            kSecClass:        kSecClassInternetPassword,
            kSecAttrServer:   server.host,
            kSecAttrPort:     server.port,
            kSecAttrAccount:  server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecValueData:    Data(password.utf8),
            kSecAttrLabel:    keychainLabel(for: server),
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            log.info("[Keychain] saved pwd for \(server.host):\(server.port)")
        } else {
            log.warning("[Keychain] save failed: \(status)")
        }
    }



    static func loadPassword(for server: RemoteServer) -> String {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassInternetPassword,
            kSecAttrServer:   server.host,
            kSecAttrPort:     server.port,
            kSecAttrAccount:  server.user,
            kSecAttrProtocol: protocolAttr(server.remoteProtocol),
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return "" }
        return password
    }



    static func deletePassword(for server: RemoteServer) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassInternetPassword,
            kSecAttrServer:  server.host,
            kSecAttrPort:    server.port,
            kSecAttrAccount: server.user,
        ]
        SecItemDelete(query as CFDictionary)
    }



    private static func protocolAttr(_ proto: RemoteProtocol) -> CFString {
        switch proto {
        case .sftp: return kSecAttrProtocolSSH
        case .ftp:  return kSecAttrProtocolFTP
        case .smb:  return kSecAttrProtocolSMB
        case .afp:  return kSecAttrProtocolAFP
        }
    }
}
