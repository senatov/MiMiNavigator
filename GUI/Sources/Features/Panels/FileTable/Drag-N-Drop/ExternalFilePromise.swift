// ExternalFilePromise.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Exports remote and archive entries to other apps as file promises.

import AppKit
import FileModelKit
import UniformTypeIdentifiers

// MARK: - External File Promise
final class ExternalFilePromise: NSObject, NSFilePromiseProviderDelegate, @unchecked Sendable {
    enum Source: Sendable {
        case local(URL)
        case remote(path: String, provider: any RemoteFileProvider)
    }

    let name: String
    let isDirectory: Bool
    let source: Source

    init(file: CustomFile, source: Source) {
        name = file.nameStr
        isDirectory = file.isDirectory || file.isSymbolicDirectory
        self.source = source
    }

    func makeProvider() -> NSFilePromiseProvider {
        let type = isDirectory ? UTType.directory : (UTType(filenameExtension: (name as NSString).pathExtension) ?? .data)
        let provider = NSFilePromiseProvider(fileType: type.identifier, delegate: self)
        provider.userInfo = self // NSFilePromiseProvider.delegate is weak.
        return provider
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        name
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        .main
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let completion = PromiseCompletion(completionHandler)
        Task {
            do {
                try await write(to: url)
                completion.call(nil)
            } catch {
                log.error("[DragExport] failed to export '\(name)': \(error.localizedDescription)")
                completion.call(error)
            }
        }
    }

    @concurrent private func write(to destination: URL) async throws {
        let fileManager = FileManager.default
        let stagingDirectory = fileManager.temporaryDirectory.appendingPathComponent("mimi-drag-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }
        let stagedURL = stagingDirectory.appendingPathComponent(name, isDirectory: isDirectory)
        switch source {
        case .local(let sourceURL):
            try fileManager.copyItem(at: sourceURL, to: stagedURL)
        case .remote(let path, let provider):
            try await provider.downloadToLocal(remotePath: path, localPath: stagedURL.path, recursive: isDirectory)
        }
        try fileManager.copyItem(at: stagedURL, to: destination)
        log.info("[DragExport] exported '\(name)' to external application")
    }
}

// MARK: - Promise Completion
private final class PromiseCompletion: @unchecked Sendable {
    private let handler: (Error?) -> Void

    init(_ handler: @escaping (Error?) -> Void) {
        self.handler = handler
    }

    func call(_ error: Error?) {
        handler(error)
    }
}
