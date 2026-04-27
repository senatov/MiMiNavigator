// FinderSidebarRows.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Finder Sidebar Rows
extension FinderSidebarView {
    // MARK: - Section
    func section(title: String?, items: [FinderSidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                sectionHeader(title)
            }
            ForEach(items) { item in
                Button {
                    handle(item)
                } label: {
                    row(item)
                }
                .buttonStyle(.plain)
                .help(item.helpText)
                .contextMenu {
                    sidebarContextMenu(for: item)
                }
            }
        }
    }

    // MARK: - Section Header
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, FinderSidebarLayout.horizontalPadding)
            .padding(.top, 2)
    }

    // MARK: - Row
    func row(_ item: FinderSidebarItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.tint)
                .frame(width: FinderSidebarLayout.iconWidth, height: FinderSidebarLayout.iconWidth)
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if item.canUnmount {
                Image(systemName: "eject.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(height: FinderSidebarLayout.rowHeight)
        .padding(.horizontal, FinderSidebarLayout.horizontalPadding)
        .background(selectionBackground(for: item))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Context Menu
    @ViewBuilder
    func sidebarContextMenu(for item: FinderSidebarItem) -> some View {
        Button {
            log.info("[FinderSidebar] context open title='\(item.title)' target='\(item.identityKey)'")
            handle(item)
        } label: {
            Label("Open", systemImage: "folder")
        }
        Button {
            openConsole(for: item)
        } label: {
            Label("Console", systemImage: "terminal")
        }
        if let url = item.fileURL {
            Button {
                log.info("[FinderSidebar] reveal in Finder path='\(url.path)'")
                RevealInFinderService.shared.revealInFinder(url)
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }
            Button {
                copyPath(url)
            } label: {
                Label("Copy as Pathname", systemImage: "link.circle.fill")
            }
            if item.canUnmount {
                Divider()
                Button {
                    unmount(item)
                } label: {
                    Label("Unmount", systemImage: "eject")
                }
            }
        }
    }

    // MARK: - Selection Background
    func selectionBackground(for item: FinderSidebarItem) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selectedID == item.id ? Color.accentColor.opacity(0.18) : Color.clear)
    }
}
