//
//  SFTPFileProvider.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Citadel
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
            let ssh = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: user, password: password),
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
            log.error("[SFTP] connect failed: \(error.localizedDescription)")
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
}
