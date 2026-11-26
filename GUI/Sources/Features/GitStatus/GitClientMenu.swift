// GitClientMenu.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared context menu for Git status marks in both file panels.

import SwiftUI

// MARK: - Git Client Menu
@MainActor
@ViewBuilder
func gitClientMenu(repository: URL) -> some View {
    let registry = GitClientRegistry.shared
    ForEach(GitClient.allCases.filter { registry.isInstalled($0) }) { client in
        Button {
            registry.open(client, repository: repository)
        } label: {
            if client == registry.preferredClient {
                ContextMenuLabel("Open in \(client.name)", systemImage: "checkmark")
            } else {
                ContextMenuLabel("Open in \(client.name)", systemImage: "arrow.up.right.square")
            }
        }
    }
    Divider()
    Button {
        SettingsCoordinator.shared.openOnSection(.gitClients)
    } label: {
        ContextMenuLabel("Git Client Settings…", systemImage: "gearshape")
    }
}
