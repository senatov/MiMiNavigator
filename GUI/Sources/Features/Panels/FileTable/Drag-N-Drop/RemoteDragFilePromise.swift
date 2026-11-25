// RemoteDragFilePromise.swift
// Description: Delivers remote drag items as real files to external applications.

import AppKit

// MARK: - Promise Completion
private final class PromiseCompletion: @unchecked Sendable {
    let handler: (Error?) -> Void
    init(_ handler: @escaping (Error?) -> Void) { self.handler = handler }
}

// MARK: - Remote Drag File Promise
@MainActor
final class RemoteDragFilePromise: NSObject, NSFilePromiseProviderDelegate {
    private let provider: any RemoteFileProvider
    private let remotePath: String
    private let fileName: String
    private let isDirectory: Bool

    init(provider: any RemoteFileProvider, remotePath: String, fileName: String, isDirectory: Bool) {
        self.provider = provider
        self.remotePath = remotePath
        self.fileName = fileName
        self.isDirectory = isDirectory
    }

    // MARK: - Promised Name
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        fileName
    }

    // MARK: - Write Promise
    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        let completion = PromiseCompletion(completionHandler)
        Task { [provider, remotePath, isDirectory] in
            do {
                try await provider.downloadToLocal(remotePath: remotePath, localPath: url.path, recursive: isDirectory)
                completion.handler(nil)
            } catch {
                log.error("[DnD] remote file promise failed path='\(remotePath)': \(error.localizedDescription)")
                completion.handler(error)
            }
        }
    }
}
