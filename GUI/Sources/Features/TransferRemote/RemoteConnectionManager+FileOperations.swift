import FileModelKit
import Foundation

// MARK: - Remote File Operations
extension RemoteConnectionManager {
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        log.debug("\(#function) active=\(activeConnection?.displayName ?? "none")")
        let connection = try requireActiveConnection()
        let items = try await connection.provider.listDirectory(path)
        updateCurrentPath(path, for: connection.id)
        return items
    }

    func downloadFile(remotePath: String) async throws -> URL {
        log.debug(#function + " active=\(activeConnection?.displayName ?? "none")")
        let connection = try requireActiveConnection()
        log.info("\(#function) '\(remotePath)'")
        return try await connection.provider.downloadFile(remotePath: remotePath)
    }

    func navigateUp() async throws -> [RemoteFileItem] {
        let connection = try requireActiveConnection()
        let parentPath = parentPath(for: connection.currentPath)
        return try await listDirectory(parentPath)
    }
}
