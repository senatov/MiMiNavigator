// MenuBarPopoverView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact informational popover shown from the macOS menu bar item.

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
        VStack(spacing: 11) {
            header
            statusOverview
            locationCard
            issuesCard
            actionCard
            footer
        }
        .padding(14)
        .frame(width: 344)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.gradient)
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .padding(6)
            }
            .frame(width: 40, height: 40)
            .shadow(color: Color.accentColor.opacity(0.22), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("MiMiNavigator")
                    .font(.system(size: 14.5, weight: .semibold))
                Text("TEST BUILD · \(version)")
                    .font(.system(size: 9.5, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Circle()
                .fill(issues.isEmpty ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 3)
    }

    private var statusOverview: some View {
        HStack(spacing: 8) {
            metric(symbol: "memorychip", title: "Memory", value: memory)
            metric(symbol: "rectangle.split.2x1", title: "Active panel", value: activePanel)
        }
    }

    private var locationCard: some View {
        infoCard {
            Label("CURRENT LOCATION", systemImage: "folder")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(currentPath)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var issuesCard: some View {
        infoCard {
            HStack {
                Label("SYSTEM ISSUES", systemImage: issues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(issues.isEmpty ? Color.green : Color.orange)
                Spacer()
                Text(issues.isEmpty ? "CLEAR" : "\(issues.count) RECENT")
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(.secondary)
            }
            if issues.isEmpty {
                Text("No errors detected in the current session")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 7) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5).padding(.top, 5)
                        Text(issue.message)
                            .font(.system(size: 10.5))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var actionCard: some View {
        VStack(spacing: 2) {
            actionRow("Show MiMiNavigator", symbol: "macwindow", action: onShow)
            Divider().padding(.leading, 34)
            actionRow("Find Files…", symbol: "magnifyingglass", action: onFind)
            actionRow("Connect to Server…", symbol: "network", action: onConnect)
            Divider().padding(.leading, 34)
            actionRow("Settings…", symbol: "gearshape", action: onSettings)
        }
        .padding(5)
        .background(cardSurface)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Right-click the menu bar icon to open")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.red)
                    .frame(minWidth: 70, minHeight: 27)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.red.opacity(0.07))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.red.opacity(0.22), lineWidth: 0.75)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Quit MiMiNavigator")
        }
        .padding(.leading, 4)
        .padding(.top, 1)
    }

    private func metric(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(cardSurface)
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardSurface)
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 7)
            .frame(minHeight: 31)
        }
        .buttonStyle(.plain)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 1.5, y: 1)
    }
}
