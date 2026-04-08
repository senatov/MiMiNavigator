// SettingsExternalToolsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings pane — shows all external CLI tools with status badges.
//   Green = installed, red = missing + (i) button with install popover.
//   Optional tools shown first, system tools collapsed by default.

import AppKit
import SwiftUI


// MARK: - SettingsExternalToolsPane

struct SettingsExternalToolsPane: View {

    @State private var registry = ExternalToolRegistry.shared
    @State private var showSystemTools = false


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            optionalToolsSection
            systemToolsSection
            Spacer(minLength: 0)
        }
        .onAppear { registry.refreshAll() }
    }


    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("External Tools")
                .font(.system(size: 15, weight: .semibold))
            Text("MiMiNavigator uses these CLI tools for archives, network, search and diff. Missing tools disable related features — click ⓘ for install instructions.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }


    // MARK: - Optional tools (need install)

    private var optionalToolsSection: some View {
        paneGroupBox(title: "Optional Tools") {
            let optional = registry.statuses.filter { !$0.tool.isSystemTool }
            if optional.isEmpty {
                Text("No optional tools registered")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(optional) { status in
                        toolRow(status)
                        if status.id != optional.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
            }
        }
    }


    // MARK: - System tools (collapsible)

    private var systemToolsSection: some View {
        paneGroupBox(title: "System Tools") {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSystemTools.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showSystemTools ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text(showSystemTools ? "Hide system tools" : "Show \(systemStatuses.count) system tools")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                if showSystemTools {
                    VStack(spacing: 0) {
                        ForEach(systemStatuses) { status in
                            toolRow(status)
                            if status.id != systemStatuses.last?.id {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                }
            }
        }
    }


    private var systemStatuses: [ToolStatus] {
        registry.statuses.filter { $0.tool.isSystemTool }
    }


    // MARK: - Single tool row

    private func toolRow(_ status: ToolStatus) -> some View {
        HStack(spacing: 10) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(status.isAvailable ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 22, height: 22)
                Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(status.isAvailable ? Color.green : Color.red)
            }
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(status.tool.name)
                    .font(.system(size: 13, weight: .medium))
                if let path = status.resolvedPath {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(status.tool.purpose)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // (i) button for missing tools
            if !status.isAvailable {
                ExternalToolInfoButton(tool: status.tool)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }


    // MARK: - Group Box

    private func paneGroupBox<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .light))
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
        }
    }
}
