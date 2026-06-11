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
            let providers = CloudDriveAvailability.shareProviders
            if providers.count > 1 {
                ForEach(providers, id: \.rawValue) { provider in
                    cloudProviderMenu(provider)
                }
            } else if let provider = providers.first {
                cloudProviderActions(provider)
            } else {
                Text("No supported cloud drive connected")
            }
        } label: {
            Label {
                Text("Share+Link")
            } icon: {
                Image(systemName: "link.badge.plus")
            }
        }
    }

    // MARK: - Cloud Provider Menu

    @ViewBuilder
    private func cloudProviderMenu(_ provider: CloudProvider) -> some View {
        Menu {
            cloudProviderActions(provider)
        } label: {
            Label(provider.rawValue, systemImage: provider.systemImage)
        }
    }

    // MARK: - Cloud Provider Actions

    @ViewBuilder
    private func cloudProviderActions(_ provider: CloudProvider) -> some View {
        Button {
            CloudLinkService.generateLink(for: file.urlValue, provider: provider, permission: .readOnly)
        } label: {
            Label("View only", systemImage: "eye")
        }
        if provider == .googleDrive {
            Button {
                CloudLinkService.generateLink(for: file.urlValue, provider: provider, permission: .allowEdit)
            } label: {
                Label("Allow editing", systemImage: "pencil")
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
