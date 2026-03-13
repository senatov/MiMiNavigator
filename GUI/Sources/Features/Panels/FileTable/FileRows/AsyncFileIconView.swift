//
//  AsyncFileIconView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import SwiftUI

// MARK: - AsyncFileIconView
struct AsyncFileIconView: View {

    let file: CustomFile

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "doc")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .task(id: file.urlValue.path) {
            await loadIcon()
        }
    }

    // MARK: - loadIcon
    private func loadIcon() async {
        let url = file.urlValue
        // Pass isDirectory explicitly so FileIconCache handles symlink-to-dir correctly
        // (url.hasDirectoryPath is false for symlinks without trailing slash)
        let isDir = file.isDirectory
        let loaded = await MainActor.run {
            FileIconCache.shared.icon(for: url, isDirectory: isDir)
        }
        self.icon = loaded
    }
}
