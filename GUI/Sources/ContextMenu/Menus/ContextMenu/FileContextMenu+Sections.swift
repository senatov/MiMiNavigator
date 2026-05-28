// FileContextMenu+Sections.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Section composition for FileContextMenu.

import SwiftUI

// MARK: - Sections

extension FileContextMenu {
    // MARK: - Menu Content
    @ViewBuilder
    var menuContent: some View {
        ForEach(sectionOrder, id: \.self) { section in
            sectionView(for: section)
        }
    }

    // MARK: - Section View
    @ViewBuilder
    func sectionView(for section: SectionKind) -> some View {
        switch section {
        case .media: mediaSection
        case .open: openSection
        case .edit: editSection
        case .operations: operationsSection
        case .navigation: navigationSection
        case .danger: dangerSection
        case .info: infoSection
        case .favorites: favoritesSection
        }
    }

    // MARK: - Media
    @ViewBuilder
    var mediaSection: some View {
        if isMediaFile {
            Button {
                FileContextMenuLog.logMediaInfo(fileName: file.nameStr, path: filePath)
                MediaInfoGetter().getMediaInfoToFile(url: file.urlValue)
            } label: {
                HStack(spacing: 5) {
                    Text("Media􀅴 & Convert")
                    Image(systemName: "info.circle")
                    Text("+")
                    Text("Convert")
                }
            }
            sectionDivider(after: .media)
        }
    }

    // MARK: - Open
    @ViewBuilder
    var openSection: some View {
        menuButton(.open)
        if file.isAppBundle || file.isArchiveFile {
            menuButton(.browseContents)
        }
        OpenWithSubmenu(file: file, apps: resolvedApps)
        menuButton(.openInNewTab)
        menuButton(.viewLister)
        archiveSourceIndicator
        sectionDivider(after: .open)
    }

    // MARK: - Edit
    @ViewBuilder
    var editSection: some View {
        menuButton(.copyAsPathname)
        sectionDivider(after: .edit)
    }

    // MARK: - Operations
    @ViewBuilder
    var operationsSection: some View {
        menuButton(.compress)
        menuButton(.share)
        sectionDivider(after: .operations)
    }

    // MARK: - Navigation
    @ViewBuilder
    var navigationSection: some View {
        menuButton(.revealInFinder)
        menuButton(.console)
        sectionDivider(after: .navigation)
    }

    // MARK: - Danger
    @ViewBuilder
    var dangerSection: some View {
        moreFileOperationsMenu
        sectionDivider(after: .danger)
    }

    // MARK: - Info
    @ViewBuilder
    var infoSection: some View {
        menuButton(.getInfo)
    }

    // MARK: - Favorites
    @ViewBuilder
    var favoritesSection: some View {
        menuButton(.mirrorPanel)
        menuButton(.addToFavorites)
        cloudLinkSection
    }
}
