// FileOpsEngine+StreamCopy.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Stream-based file copy with live byte progress via AsyncStream.

import Foundation

// MARK: - Stream Copy

extension FileOpsEngine {

    func streamCopy(from source: URL, to destination: URL, progress: FileOpProgress) async throws {
        let bytesChannel = AsyncStream<Int64>.makeStream()
        let copyTask = Task.detached(priority: .userInitiated) {
            Self.performStreamCopy(from: source, to: destination, onChunk: { bytes in
                bytesChannel.continuation.yield(bytes)
            })
        }
        let consumer = Task { @MainActor in
            for await chunk in bytesChannel.stream {
                progress.add(bytes: chunk)
            }
        }
        let result = await copyTask.value
        bytesChannel.continuation.finish()
        await consumer.value
        if case .failure(let error) = result {
            throw error
        }
    }



    nonisolated static func performStreamCopy(
        from source: URL, to destination: URL,
        onChunk: @Sendable (Int64) -> Void = { _ in }
    ) -> Result<Void, FileOpError> {
        guard let input = InputStream(url: source) else { return .failure(.fileNotFound(source.path)) }
        guard let output = OutputStream(url: destination, append: false) else { return .failure(.invalidDest(destination.path)) }
        input.open(); output.open()
        defer { input.close(); output.close() }
        let bufSize = 1024 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        while true {
            let read = input.read(buffer, maxLength: bufSize)
            if read < 0 { return .failure(.readFailed(source.path)) }
            if read == 0 { break }
            let written = output.write(buffer, maxLength: read)
            if written < 0 { return .failure(.writeFailed(source.path)) }
            onChunk(Int64(written))
        }
        return .success(())
    }
}
