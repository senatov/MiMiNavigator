import Darwin
import FileModelKit
import Foundation

// MARK: - Background-only icon content inspection
struct IconContentInspection: Sendable {
    var isEncrypted = false
    var kind: DetectedFileKind = .unknown
    // MARK: - Inspect locally available regular files
    static func inspect(url: URL, isDirectory: Bool) -> Self {
        guard !isDirectory, url.isFileURL else { return .init() }
        let ext = url.pathExtension.lowercased()
        guard ext.isEmpty || ["zip", "7z", "rar"].contains(ext) else { return .init() }
        let resolvedURL = url.resolvingSymlinksInPath()
        guard allowsContentRead(path: resolvedURL.path) else { return .init() }
        var info = stat()
        guard lstat(resolvedURL.path, &info) == 0,
              (info.st_mode & S_IFMT) == S_IFREG,
              (info.st_flags & UInt32(SF_DATALESS)) == 0 else { return .init() }
        if ext.isEmpty {
            return .init(kind: FileMagicDetector.detect(url: resolvedURL))
        }
        return .init(isEncrypted: EncryptedArchiveCheck.isEncrypted(url: resolvedURL))
    }
    // MARK: - Avoid provider downloads for decorative icons
    static func allowsContentRead(path: String) -> Bool {
        let components = URL(fileURLWithPath: path).standardized.pathComponents
        for index in components.indices where components[index] == "Library" {
            guard index + 1 < components.count else { continue }
            if ["CloudStorage", "Mobile Documents"].contains(components[index + 1]) {
                return false
            }
        }
        return true
    }
}
