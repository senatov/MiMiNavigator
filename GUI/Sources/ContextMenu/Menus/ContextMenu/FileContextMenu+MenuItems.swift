// FileContextMenu+MenuItems.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Menu item builders for FileContextMenu.

import SwiftUI

// MARK: - Menu Items

extension FileContextMenu {
    // MARK: - File Operations Menu
    @ViewBuilder
    var moreFileOperationsMenu: some View {
        Menu {
            menuButton(.newFolder)
            menuButton(.newFile)
            menuButton(.rename)
            Divider()
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            menuButton(.duplicate)
            Divider()
            menuButton(.createLink)
            menuButton(.delete)
        } label: {
            Label {
                Text("􀉒 File Operations")
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Cloud Link
    @ViewBuilder
    var cloudLinkSection: some View {
        Divider()
        Menu {
            Button {
                CloudLinkService.generateLink(for: file.urlValue, provider: .googleDrive, permission: .readOnly)
            } label: {
                Label("View only", systemImage: "eye")
            }
            Button {
                CloudLinkService.generateLink(for: file.urlValue, provider: .googleDrive, permission: .allowEdit)
            } label: {
                Label("Allow editing", systemImage: "pencil")
            }
        } label: {
            Label {
                Text("Share+Link")
            } icon: {
                Image(systemName: "link.badge.plus")
            }
        }
    }

    // MARK: - Archive Source
    @ViewBuilder
    var archiveSourceIndicator: some View {
        if file.isFromArchiveSearch, let archivePath = file.archiveSourcePath {
            Label {
                Text("In: \((archivePath as NSString).lastPathComponent)")
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "archivebox")
                    .foregroundStyle(.orange)
            }
            .font(.caption)
        }
    }

    // MARK: - Section Divider
    @ViewBuilder
    func sectionDivider(after section: SectionKind) -> some View {
        if shouldShowDivider(after: section) {
            Divider()
        }
    }

    // MARK: - Menu Button
    @ViewBuilder
    func menuButton(_ action: FileAction) -> some View {
        Button {
            performAction(action)
        } label: {
            menuLabel(for: action)
        }
        .disabled(isActionDisabled(action))
    }
}
