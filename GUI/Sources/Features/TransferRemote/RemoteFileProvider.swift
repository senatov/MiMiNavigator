// RemoteFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Protocol for remote file access (SFTP, FTP, SMB, AFP).
//   Implementations: SFTPFileProvider, FTPFileProvider, NoOpRemoteFileProvider.

import FileModelKit
import Foundation


// MARK: - RemoteFileProvider

protocol RemoteFileProvider: AnyObject, Sendable {
    var isConnected: Bool { get }
    var mountPath: String { get }
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem]
    /// Downloads a remote file to a local temp URL. Returns the local URL.
    @concurrent func downloadFile(remotePath: String) async throws -> URL
    /// Downloads file or directory to a specific local path. `recursive` enables dir tree copy.
    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws
    @concurrent func disconnect() async
}
