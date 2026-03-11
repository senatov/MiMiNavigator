//
//  AsyncFileIconView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import SwiftUI

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

    private func loadIcon() async {
        let path = file.urlValue.path

        let icon = await MainActor.run {
            FileIconCache.shared.icon(for: path)
        }

        self.icon = icon
    }
}
