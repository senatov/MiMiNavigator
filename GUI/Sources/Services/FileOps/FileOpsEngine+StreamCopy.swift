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

    // MARK: - Perform Stream Copy
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
            guard writeFully(buffer, count: read, write: { output.write($0, maxLength: $1) }, onChunk: onChunk) else {
                return .failure(.writeFailed(destination.path))
            }
        }
        return .success(())
    }

    // MARK: - Write Fully
    nonisolated static func writeFully(
        _ buffer: UnsafePointer<UInt8>,
        count: Int,
        write: (UnsafePointer<UInt8>, Int) -> Int,
        onChunk: (Int64) -> Void
    ) -> Bool {
        var offset = 0
        while offset < count {
            let written = write(buffer.advanced(by: offset), count - offset)
            guard written > 0, written <= count - offset else { return false }
            offset += written
            onChunk(Int64(written))
        }
        return true
    }
}
