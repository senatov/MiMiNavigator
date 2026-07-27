// SettingsPermissionsComponents.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Liquid Glass cards and native permission presentation components.

import SwiftUI

// MARK: - Permissions Glass Card

struct PermissionsGlassCard<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: 20))
    }
}

// MARK: - Permissions Dimensional Icon

struct PermissionsDimensionalIcon: View {
    let systemName: String
    let tint: Color
    let badgeSystemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.92), tint.opacity(0.50)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.48), lineWidth: 1)
                        .padding(1)
                }
                .shadow(color: tint.opacity(0.30), radius: 10, y: 6)
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.20), radius: 2, y: 2)
            Image(systemName: badgeSystemName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, tint)
                .font(.system(size: 14, weight: .bold))
                .padding(5)
                .background(.ultraThickMaterial, in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.62), lineWidth: 1) }
                .offset(x: 20, y: 20)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

// MARK: - Permissions Status Capsule

struct PermissionsStatusCapsule: View {
    let title: String
    let systemName: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.22), lineWidth: 0.5) }
    }
}

// MARK: - Permissions Feature Grid

struct PermissionsFeatureGrid: View {
    let items: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
            ForEach(items, id: \.1) { item in
                Label(item.1, systemImage: item.0)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(.background.opacity(0.32), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Permissions Empty Folders View

struct PermissionsEmptyFoldersView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No authorized folders")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add only the locations you want to expose to MiMiNavigator.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.background.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Permissions Folder Row

struct PermissionsFolderRow: View {
    let folder: AuthorizedFolder
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : .indigo)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(folder.path)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Label(
                    folder.isAccessible ? "Available" : "Reauthorization needed",
                    systemImage: folder.isAccessible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? .white : (folder.isAccessible ? Color.green : Color.orange))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions Access Comparison

struct PermissionsAccessComparison: View {
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            comparisonRow(
                icon: "lock.shield.fill",
                title: "Full Disk Access",
                detail: "System-wide protected locations",
                owner: "System Settings"
            )
            Divider().gridCellColumns(3)
            comparisonRow(
                icon: "folder.fill",
                title: "Authorized Folders",
                detail: "Only folders you explicitly choose",
                owner: "MiMiNavigator"
            )
        }
        .font(.system(size: 11))
        .padding(12)
        .background(.background.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Comparison Row

    private func comparisonRow(icon: String, title: String, detail: String, owner: String) -> some View {
        GridRow {
            Label(title, systemImage: icon)
                .fontWeight(.semibold)
            Text(detail)
                .foregroundStyle(.secondary)
            Text(owner)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
