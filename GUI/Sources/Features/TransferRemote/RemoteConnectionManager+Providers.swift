//
//  RemoteConnectionManager+Providers.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 04.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Provider Factory
extension RemoteConnectionManager {

    func createProvider(for server: RemoteServer) -> (any RemoteFileProvider)? {
        let proto = server.remoteProtocol
        log.debug("\(#function)(\(proto))")
        switch proto {
        case .sftp:
            return SFTPFileProvider(authType: server.authType, privateKeyPath: server.privateKeyPath)
        case .ftp:
            return FTPFileProvider()
        case .smb:
            return SMBFileProvider()
        default:
            log.warning("[RemoteConnectionManager] provider unavailable for protocol=\(proto.rawValue)")
            log.warning("[RemoteConnectionManager] only FTP, SFTP, and SMB providers are currently implemented")
            return nil
        }
    }
}

// MARK: - Error Classification
extension RemoteConnectionManager {

    func classifyError(_ error: Error) -> ConnectionResult {
        log.debug("\(#function)(\(error))")
        let raw = String(describing: error).lowercased()
        let message = error.localizedDescription.lowercased()
        if let providerError = error as? RemoteProviderError {
            switch providerError {
            case .authFailed:
                return .authFailed
            case .notConnected, .notImplemented, .invalidURL, .listingFailed, .downloadFailed:
                return .error
            @unknown default:
                log.warning("\(#function): unhandled RemoteProviderError=\(providerError)")
                return .error
            }
        }
        if message.contains("timeout") || message.contains("timed out") || raw.contains("connecttimeout") || raw.contains("timed out") {
            return .timeout
        }
        if message.contains("refused") || message.contains("connection refused") || raw.contains("connection refused") {
            return .refused
        }
        if isAuthenticationError(message: message, raw: raw) {
            return .authFailed
        }
        return .error
    }

    func detailedErrorDescription(_ error: Error) -> String {
        let described = String(describing: error)
        guard !described.isEmpty else { return error.localizedDescription }
        return described
    }

    private func isAuthenticationError(message: String, raw: String) -> Bool {
        message.contains("auth")
            || message.contains("password")
            || message.contains("denied")
            || raw.contains("allauthenticationoptionsfailed")
            || raw.contains("unsupportedpasswordauthentication")
    }
}
