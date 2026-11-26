import Foundation

// MARK: - Volume Location
struct VolumeLocation: Identifiable {
    enum Kind: Equatable {
        case mounted
        case kindle
        case cloud
        case remote
    }
    let id: String
    let title: String
    let url: URL
    let kind: Kind
    let connectionID: UUID?
    var capacity: VolumeStatusInfo.Capacity? = nil
    var canEject = false
    var canOpen = true

    // MARK: - Kindle Documents Shortcut
    var kindleDocuments: VolumeLocation? {
        guard kind == .mounted, canOpen, url.deletingLastPathComponent().path == "/Volumes",
              title.localizedCaseInsensitiveContains("kindle") || url.lastPathComponent.localizedCaseInsensitiveContains("kindle")
        else { return nil }
        let fileManager = FileManager.default
        for name in ["documents", "Documents"] {
            let folder = url.appendingPathComponent(name, isDirectory: true)
            guard let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink == false,
                  fileManager.isReadableFile(atPath: folder.path)
            else { continue }
            return VolumeLocation(id: "kindle:\(id)", title: "\(title) — Documents", url: folder, kind: .kindle, connectionID: nil)
        }
        return nil
    }
}
