//
//  RemoteSrKeyChain+Hlp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import LocalAuthentication
import Security

// MARK: - Helpers

extension RemoteServerKeychain {

    static func keychainLabel(for server: RemoteServer) -> String {
        "MiMiNavigator-Remote: \(server.host):\(server.port)"
    }

    static func keychainAccessibility() -> CFString {
        kSecAttrAccessibleAfterFirstUnlock
    }

    static func nonInteractiveAuthenticationContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }

    static func endpointKey(for server: RemoteServer) -> String {
        let host = server.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let user = server.user.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = server.remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(server.remoteProtocol.rawValue)|\(host)|\(server.port)|\(user)|\(path)"
    }

    static func endpointDescription(for server: RemoteServer) -> String {
        "\(server.remoteProtocol.rawValue.uppercased())://\(server.user)@\(server.host):\(server.port)"
    }

    static func statusDescription(_ status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Unknown OSStatus"
    }

    static func logKeychainFailure(_ action: String, status: OSStatus, server: RemoteServer) {
        log.error(
            "[Keychain] \(action) failed for \(endpointDescription(for: server)) status=\(status) message='\(statusDescription(status))'"
        )
    }

    static func protocolAttr(_ proto: RemoteProtocol) -> CFString {
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
