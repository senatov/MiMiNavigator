// MenuBarPopoverView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Menu bar actions presented with the shared dialog components.

import SwiftUI

// MARK: - Menu Bar Popover View
struct MenuBarPopoverView: View {
    let version: String
    let memory: String
    let activePanel: String
    let currentPath: String
    let issues: [MenuBarSystemIssue]
    let onShow: () -> Void
    let onFind: () -> Void
    let onConnect: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HIGDialogHeader("MiMiNavigator", subtitle: "TEST BUILD · \(version)")
            informationGroup
            actionsGroup
            DialogFooter {
                DownToolbarButtonView(title: "Quit", systemImage: "power", iconTint: .red, action: onQuit)
                    .frame(minWidth: 105, minHeight: 41)
                    .focusable(false)
            }
        }
        .higDialogStyle()
    }

    // MARK: - Information
    private var informationGroup: some View {
        SettingsGroupBox {
            informationRow("Memory", value: memory)
            Divider()
            informationRow("Active panel", value: activePanel)
            Divider()
            informationRow("Current location", value: currentPath)
            Divider()
            SettingsRow(label: "System issues", help: "Issues in the current session", labelWidth: 125) {
                Text(issues.isEmpty ? "No errors detected" : "\(issues.count) recent")
                    .foregroundStyle(issues.isEmpty ? Color.secondary : Color.orange)
            }
            if !issues.isEmpty {
                ForEach(issues) { issue in
                    Text(issue.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func informationRow(_ label: String, value: String) -> some View {
        SettingsRow(label: label, help: label, labelWidth: 125) {
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }

    // MARK: - Actions
    private var actionsGroup: some View {
        SettingsGroupBox {
            actionRow("Show MiMiNavigator", symbol: "macwindow", action: onShow)
            Divider()
            actionRow("Find Files…", symbol: "magnifyingglass", action: onFind)
            Divider()
            actionRow("Connect to Server…", symbol: "network", action: onConnect)
            Divider()
            actionRow("Settings…", symbol: "gearshape", action: onSettings)
        }
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
