// FileRowView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: File row content view — icon + name.
//              Icon logic extracted to SmartIconService.swift.
//              Async icon loading via AsyncSmartIconView (nested).

import AppKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File row content view (icon + name)
struct FileRowView: View {
    let file: CustomFile
    let isSelected: Bool
    let isActivePanel: Bool
    var isMarked: Bool = false
    // Optional interaction callbacks (can be ignored by caller)
    var onSelect: (CustomFile) -> Void = { _ in }
    var onDoubleClick: (CustomFile) -> Void = { _ in }
    private let colorStore = ColorThemeStore.shared

    // MARK: - Constants
    private static let nameWeight: Font.Weight = .light
    private static let nameFontSize: CGFloat = 14

    // MARK: - View Body
    var body: some View {
        baseContent()
            .padding(.vertical, DesignTokens.grid / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    // MARK: - Parent entry check
    private var isParentEntry: Bool {
        // Primary check
        if ParentDirectoryEntry.isParentEntry(file) { return true }
        // Fallback for synthetic rows
        return file.nameStr == ".."
    }

    // MARK: - Name color
    private var nameColor: Color {
        if isMarked { return colorStore.activeTheme.markedFileColor }
        if isParentEntry { return colorStore.activeTheme.parentEntryColor }
        if file.isHidden { return colorStore.activeTheme.hiddenFileColor }
        if file.isSymbolicLink { return colorStore.activeTheme.symlinkColor }
        if file.isDirectory { return colorStore.activeTheme.dirNameColor }
        return colorStore.activeTheme.fileNameColor
    }

    // MARK: - Icon opacity (dimming for hidden files)
    private var iconOpacity: Double {
        file.isHidden ? 0.45 : 1.0
    }

    // MARK: - Base content
    @ViewBuilder
    private func baseContent() -> some View {
        if isParentEntry {
            ParentEntryStripView(
                file: file,
                isSelected: isSelected,
                parentURL: file.urlValue,
                onSelect: onSelect,
                onActivate: onDoubleClick
            )
        } else {
            normalFileRow
        }
    }

    // MARK: - Normal file row
    private var normalFileRow: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncSmartIconView(file: file)
                    .frame(width: DesignTokens.Row.iconSize, height: DesignTokens.Row.iconSize)
                    .opacity(iconOpacity)
                    .allowsHitTesting(false)
                switch file.securityState {
                    case .restricted:
                        Image(systemName: "lock.square.stack")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                Color(#colorLiteral(red: 0.3098039329, green: 0.01568627544, blue: 0.1294117719, alpha: 1))
                            )
                            .offset(x: 2, y: 2)
                    case .systemProtected:
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                Color(#colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1))
                            )
                            .offset(x: 2, y: 2)
                    case .immutable:
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                Color(#colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1))
                            )
                            .offset(x: 2, y: 2)
                    case .brokenSymlink:
                        Image(systemName: "exclamationmark.link")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))
                            )
                            .offset(x: 2, y: 2)
                    case .specialDevice:
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
                            )
                            .offset(x: 2, y: 2)
                    case .normal:
                        EmptyView()
                }
            }
            .layoutPriority(1)
            HStack(spacing: 4) {
                if isMarked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colorStore.activeTheme.markedFileColor)
                }
                Text(file.nameStr)
                    .font(.system(size: Self.nameFontSize, weight: Self.nameWeight))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .overlay(alignment: .trailing) {
                FileInfoButton(file: file, isSelected: isSelected)
            }
            .layoutPriority(0)
        }
    }
}
