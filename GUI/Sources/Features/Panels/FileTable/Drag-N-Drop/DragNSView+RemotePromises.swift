// DragNSView+RemotePromises.swift
// Description: Creates file promises for remote drag items.

import AppKit
import FileModelKit

// MARK: - Remote Drag Promises
extension DragNSView {
    func makeRemoteDragPromises(files: [CustomFile], urls: [URL]) -> [Int: NSFilePromiseProvider]? {
        var promisedWriters: [Int: NSFilePromiseProvider] = [:]
        remoteDragPromises = []
        for (index, file) in files.enumerated() {
            guard index < urls.count else { break }
            let remoteURL = panelSide.flatMap { appState?.remoteURL(for: file.pathStr, on: $0) } ?? urls[index]
            guard AppState.isRemotePath(remoteURL) else { continue }
            guard let connection = RemoteConnectionManager.shared.connection(for: remoteURL) else {
                log.error("[DnD] no connection for remote drag path='\(remoteURL.path)'")
                return nil
            }
            let promise = RemoteDragFilePromise(provider: connection.provider, remotePath: remoteURL.path, fileName: file.nameStr, isDirectory: file.isDirectory)
            let fileType = file.isDirectory ? "public.folder" : "public.data"
            let writer = NSFilePromiseProvider(fileType: fileType, delegate: promise)
            writer.userInfo = promise
            promisedWriters[index] = writer
            remoteDragPromises.append(promise)
        }
        return promisedWriters
    }
}
