//
//  TopParentDirectoryContol.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Compact sticky strip above the file table.
//               Shows parent directory name + file count, flanked by chevron.up.2 icons.

import FileModelKit
import Foundation
import SwiftUI

// MARK: - TopParentDirectoryControl
/// Slim light-gray strip above the file table.
/// Center: ⌃⌃  /ParentDir (N)  ⌃⌃  — single/double tap both navigate up.
struct TopParentDirectoryControl: View {
    let currentPath: String
    let fileCount: Int
    private let textColor = Color(#colorLiteral(red: 0.30, green: 0.30, blue: 0.32, alpha: 1))
    private let chevronColor = Color(#colorLiteral(red: 0.55, green: 0.55, blue: 0.58, alpha: 1))
    let onNavigateUp: () -> Void
    // MARK: - label
    private var label: String { "/\(parentName) (\(fileCount))" }

    @State private var isHovering = false
    // MARK: - parentName
    private var parentName: String {
        URL(fileURLWithPath: currentPath)
            .deletingLastPathComponent()
            .lastPathComponent
            .nonEmpty ?? "/"
    }

    // MARK: - bgColor
    private var bgColor: Color {
        isHovering
            ? Color(#colorLiteral(red: 0.88, green: 0.88, blue: 0.90, alpha: 1))
            : Color(#colorLiteral(red: 0.94, green: 0.94, blue: 0.95, alpha: 1))
    }

    // MARK: - body
    var body: some View {
        HStack(spacing: 5) {
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.2")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(chevronColor)
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.up.2")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(chevronColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 18)
        .background(bgColor)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.10)) { isHovering = h } }
        .onTapGesture(count: 2) { onNavigateUp() }
        .onTapGesture { onNavigateUp() }
        .help("Go to parent directory")
    }
}

// MARK: - String helper
extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}
