//
//  SFTPFileProvider.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Citadel
import Crypto
import FileModelKit
import Foundation
import NIO
import NIOSSH

final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    // MARK: - Connection State

    private(set) var isConnected = false
    private(set) var mountPath = ""

    var sshClient: SSHClient?
    var sftpClient: SFTPClient?
    var host = ""
    var port = 22
    var username = ""
    var remoteRootPath = "/"
    private let authType: RemoteAuthType
    private let privateKeyPath: String

    // MARK: - Init

    init(authType: RemoteAuthType = .password, privateKeyPath: String = "") {
        self.authType = authType
        self.privateKeyPath = privateKeyPath
    }

    // MARK: - Lifecycle

    private func resetSession() {
        isConnected = false
        mountPath = ""
        sshClient = nil
        sftpClient = nil
        host = ""
        port = 22
        username = ""
        remoteRootPath = "/"
    }

    func requireSSHClient(function: String = #function) throws -> SSHClient {
        guard let sshClient else {
            log.error("[SFTP] \(function) failed: SSH client is not connected")
            throw RemoteProviderError.notConnected
        }

        return sshClient
    }

    func requireSFTPClient(function: String = #function) throws -> SFTPClient {
        guard let sftpClient else {
            log.error("[SFTP] \(function) failed: SFTP client is not connected")
            throw RemoteProviderError.notConnected
        }

        return sftpClient
    }

    private func normalizedRemoteRootPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    static func buildMountPath(host: String, port: Int, user: String, remotePath: String) -> String {
        let normalizedPath: String
        if remotePath.isEmpty {
            normalizedPath = ""
        } else if remotePath.hasPrefix("/") {
            normalizedPath = remotePath
        } else {
            normalizedPath = "/\(remotePath)"
        }

        let portSuffix = port == 22 ? "" : ":\(port)"
        return "sftp://\(user)@\(host)\(portSuffix)\(normalizedPath)"
    }

    // MARK: - Connection

    @concurrent
    func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.debug("[SFTP] connect host=\(host) port=\(port)")
        log.debug("[SFTP] user=\(user) remotePath=\(remotePath)")
        log.debug("[SFTP] password provided=\(!password.isEmpty)")

        let normalizedRoot = normalizedRemoteRootPath(remotePath)

        do {
            let authenticationMethod = try makeAuthenticationMethod(user: user, password: password)
            let ssh = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: authenticationMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )

            let sftp = try await ssh.openSFTP()

            sshClient = ssh
            sftpClient = sftp
            self.host = host
            self.port = port
            username = user
            remoteRootPath = normalizedRoot
            mountPath = Self.buildMountPath(
                host: host,
                port: port,
                user: user,
                remotePath: normalizedRoot == "/" ? "" : normalizedRoot
            )
            isConnected = true

            log.info("[SFTP] connected → \(mountPath)")
        } catch {
            resetSession()
            log.error("[SFTP] connect failed: \(Self.errorDescription(error))")
            throw error
        }
    }

    @concurrent
    func disconnect() async {
        let currentSSHClient = sshClient
        resetSession()

        do {
            try await currentSSHClient?.close()
        } catch {
            log.warning("[SFTP] disconnect warning: \(error.localizedDescription)")
        }

        log.info("[SFTP] disconnected")
    }

    // MARK: - Authentication
    private func makeAuthenticationMethod(user: String, password: String) throws -> SSHAuthenticationMethod {
        switch authType {
            case .password:
                return .passwordBased(username: user, password: password)
            case .privateKey:
                return try privateKeyAuthentication(user: user, password: password, keyPath: expandedPrivateKeyPath())
            case .agent:
                return try agentFallbackAuthentication(user: user, password: password)
        }
    }

    // MARK: - Private Key Authentication
    private func privateKeyAuthentication(user: String, password: String, keyPath: String) throws -> SSHAuthenticationMethod {
        let keyData = try Data(contentsOf: URL(fileURLWithPath: keyPath))
        let decryptionKey = password.isEmpty ? nil : Data(password.utf8)
        if let method = try? ed25519Authentication(user: user, keyData: keyData, decryptionKey: decryptionKey) {
            return method
        }
        if let method = try? rsaAuthentication(user: user, keyData: keyData, decryptionKey: decryptionKey) {
            return method
        }
        throw RemoteProviderError.authFailed
    }

    // MARK: - Agent Fallback Authentication
    private func agentFallbackAuthentication(user: String, password: String) throws -> SSHAuthenticationMethod {
        for keyPath in defaultPrivateKeyPaths() where FileManager.default.fileExists(atPath: keyPath) {
            if let method = try? privateKeyAuthentication(user: user, password: password, keyPath: keyPath) {
                return method
            }
        }
        throw RemoteProviderError.authFailed
    }

    // MARK: - Key Type Authentication
    private func ed25519Authentication(user: String, keyData: Data, decryptionKey: Data?) throws -> SSHAuthenticationMethod {
        let privateKey = try Curve25519.Signing.PrivateKey(sshEd25519: keyData, decryptionKey: decryptionKey)
        return .ed25519(username: user, privateKey: privateKey)
    }

    private func rsaAuthentication(user: String, keyData: Data, decryptionKey: Data?) throws -> SSHAuthenticationMethod {
        let privateKey = try Insecure.RSA.PrivateKey(sshRsa: keyData, decryptionKey: decryptionKey)
        return .rsa(username: user, privateKey: privateKey)
    }

    // MARK: - Key Paths
    private func expandedPrivateKeyPath() -> String {
        let trimmedPath = privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmedPath.isEmpty ? "~/.ssh/id_rsa" : trimmedPath
        guard path.hasPrefix("~/") else { return path }
        return NSHomeDirectory() + "/" + path.dropFirst(2)
    }

    private func defaultPrivateKeyPaths() -> [String] {
        [
            "~/.ssh/id_ed25519",
            "~/.ssh/id_rsa",
        ].map { path in
            NSHomeDirectory() + "/" + path.dropFirst(2)
        }
    }

    // MARK: - Error Description
    static func errorDescription(_ error: Error) -> String {
        let described = String(describing: error)
        guard !described.isEmpty else { return error.localizedDescription }
        return described
    }
}
