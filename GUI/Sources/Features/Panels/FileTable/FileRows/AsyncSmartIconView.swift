//
//  AsyncSmartIconView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Async icon loader
struct AsyncSmartIconView: View {
    let file: CustomFile
    @State private var icon: NSImage?
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "doc")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            // Lock overlay for restricted/read-only directories
            if file.isDirectory && file.securityState != .normal {
                lockOverlay
            }
        }
        .task(id: file.urlValue.path) {
            icon = SmartIconService.icon(for: file)
            let url = file.urlValue
            let isDirectory = file.isDirectory
            let content = await Task.detached(priority: .utility) {
                IconContentInspection.inspect(url: url, isDirectory: isDirectory)
            }.value
            guard !Task.isCancelled else { return }
            icon = SmartIconService.icon(for: file, content: content)
        }
    }

    /// Lock badge for restricted directories (read-only, system protected, etc.)
    @ViewBuilder
    private var lockOverlay: some View {
        Image(systemName: lockSymbol)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(lockColor)
            .background(
                Circle()
                    .fill(.background.opacity(0.85))
                    .frame(width: 11, height: 11)
            )
            .offset(x: 2, y: 2)
            .help(lockTooltip)
    }

    private var lockSymbol: String {
        switch file.securityState {
            case .restricted: return "lock.fill"
            case .systemProtected: return "lock.shield.fill"
            case .immutable: return "lock.doc.fill"
            case .brokenSymlink: return "exclamationmark.triangle.fill"
            case .specialDevice: return "cpu.fill"
            case .normal: return ""
        }
    }

    private var lockColor: Color {
        switch file.securityState {
            case .restricted: return .orange
            case .systemProtected: return .red
            case .immutable: return .purple
            case .brokenSymlink: return .yellow
            case .specialDevice: return .gray
            case .normal: return .clear
        }
    }

    private var lockTooltip: String {
        switch file.securityState {
            case .restricted: return "Read-only (no write access)"
            case .systemProtected: return "System protected directory"
            case .immutable: return "Immutable (locked file)"
            case .brokenSymlink: return "Broken symbolic link"
            case .specialDevice: return "Special device"
            case .normal: return ""
        }
    }
}
