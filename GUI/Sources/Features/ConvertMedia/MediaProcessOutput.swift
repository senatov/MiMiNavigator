import Foundation

// MARK: - Bounded process output
final class MediaProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var tail = Data()
    private var totalBytes = 0
    private let limit = 32 * 1_024

    // MARK: - Read serialized pipe output
    func read(_ handle: FileHandle, toEnd: Bool = false) -> String {
        lock.lock()
        defer { lock.unlock() }
        let data = toEnd ? handle.readDataToEndOfFile() : handle.availableData
        totalBytes += data.count
        tail.append(data)
        if tail.count > limit { tail = Data(tail.suffix(limit)) }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Diagnostic snapshot
    func snapshot() -> (text: String, bytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (String(decoding: tail, as: UTF8.self), totalBytes)
    }
}
