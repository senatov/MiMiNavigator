// TabContextMenu.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context menu for right-clicking a tab — Close, Close Others, Duplicate, Copy Path

import AppKit
import SwiftUI

// MARK: - Tab Context Menu
/// Context menu shown when right-clicking a tab in the tab bar.
/// Provides tab management actions similar to Safari/Finder tab context menus.
struct TabContextMenu: View {

    let tab: TabItem
    let isOnlyTab: Bool
    let tabCount: Int
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onDuplicate: () -> Void

    var body: some View {
        Group {
            // Close this tab
            Button {
                log.debug("[TabContextMenu] close tab '\(tab.displayName)'")
                onClose()
            } label: {
                Label {
                    HStack {
                        Text("Close Tab")
                        Spacer()
                        Text("⌘W")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "xmark")
                }
            }
            .disabled(isOnlyTab)

            // Close other tabs
            Button {
                log.debug("[TabContextMenu] close others, keeping '\(tab.displayName)'")
                onCloseOthers()
            } label: {
                Label("Close Other Tabs", systemImage: "xmark.square")
            }
            .disabled(tabCount <= 1)

            // Close tabs to the right
            Button {
                log.debug("[TabContextMenu] close tabs to right of '\(tab.displayName)'")
                onCloseToRight()
            } label: {
                Label("Close Tabs to the Right", systemImage: "arrow.right.to.line")
            }
            .disabled(tabCount <= 1)

            Divider()

            // Duplicate tab
            Button {
                log.debug("[TabContextMenu] duplicate tab '\(tab.displayName)'")
                onDuplicate()
            } label: {
                Label {
                    HStack {
                        Text("Duplicate Tab")
                        Spacer()
                    }
                } icon: {
                    Image(systemName: "plus.square.on.square")
                }
            }

            Divider()

            // Copy path to clipboard
            Button {
                log.debug("[TabContextMenu] copy path '\(tab.path)'")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            // Reveal in Finder
            Button {
                log.debug("[TabContextMenu] reveal in Finder '\(tab.path)'")
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tab.path)
            } label: {
                Label("Show in Finder", systemImage: "folder.badge.gearshape")
            }
        }
    }
}
