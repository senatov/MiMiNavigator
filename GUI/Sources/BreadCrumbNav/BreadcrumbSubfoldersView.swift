import SwiftUI

// MARK: - Subfolder chooser
struct BreadcrumbSubfoldersView: View {
    let directory: URL
    let onSelect: (URL) -> Void
    @State private var folders: [URL] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(directory.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            if isLoading {
                ProgressView("Loading subfolders…")
            } else if let errorMessage {
                Text(errorMessage).font(.callout).foregroundStyle(.secondary)
            } else if folders.isEmpty {
                Text("No subfolders").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(folders, id: \.self) { folder in
                            Button { onSelect(folder) } label: {
                                Label(folder.lastPathComponent, systemImage: "folder")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: min(CGFloat(folders.count) * 32, 280))
            }
        }
        .padding(12)
        .font(.system(size: 13))
        .controlSize(.regular)
        .frame(width: 300)
        .task(id: directory) { await loadFolders() }
    }

    // MARK: - Load on demand
    private func loadFolders() async {
        isLoading = true
        errorMessage = nil
        let target = directory
        let result = await Task.detached(priority: .userInitiated) {
            Result { () throws -> [URL] in
                let manager = FileManager.default
                let children = try manager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil, options: [])
                return children.filter { url in
                    var isDirectory: ObjCBool = false
                    return manager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let urls): folders = urls
        case .failure(let error): errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
