//
// FavTreePopupView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.10.2024.
// Updated for macOS Design Guidelines on 03.12.2024
//

import AppKit
import SwiftUI

@MainActor
struct FavTreePopupView: View {
    // MARK: - Environment / Dependencies

    @EnvironmentObject var appState: AppState
    @Binding var file: CustomFile
    @Binding var expandedFolders: Set<String>
    @Binding var isPresented: Bool

    // MARK: - Init

    init(
        file: Binding<CustomFile>,
        expandedFolders: Binding<Set<String>>,
        isPresented: Binding<Bool>
    ) {
        _file = file
        _expandedFolders = expandedFolders
        _isPresented = isPresented
        log.debug("FavTreePopupView init for file \(file.wrappedValue.nameStr)")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileRow
            childrenList
        }
        .onAppear {
            autoExpandIfNeeded()
        }
    }

    // MARK: - Computed Properties

    private var isExpanded: Bool {
        expandedFolders.contains(file.pathStr)
    }

    private var isDirectoryType: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    private var isCurrent: Bool {
        appState.selectedDir.selectedFSEntity?.pathStr == file.pathStr
    }

    private var indentLevel: Int {
        let components = file.pathStr.split(separator: "/")
        return max(0, components.count - 3)
    }

    // MARK: - Subviews

    private var fileIcon: some View {
        HStack(spacing: 4) {
            if isDirectoryType {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleExpansion()
                    }
            } else {
                Spacer().frame(width: 12)
            }

            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 16, height: 16)
        }
    }

    private var fileNameText: some View {
        HStack(spacing: 4) {
            Text(file.nameStr)
                .font(.system(size: 12))
                .foregroundColor(isCurrent ? .accentColor : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if let children = file.children, !children.isEmpty {
                Text("\(children.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleFileTap()
        }
        .help(fileInfoTooltip)
    }

    private var fileRow: some View {
        HStack(spacing: 4) {
            fileIcon
            fileNameText
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isExpanded ? Color.accentColor.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
        .padding(.leading, CGFloat(indentLevel * 16))
    }

    @ViewBuilder
    private var childrenList: some View {
        if isExpanded, let children = file.children, !children.isEmpty {
            ForEach(children.indices, id: \.self) { index in
                childView(at: index)
            }
        }
    }

    private func childView(at index: Int) -> some View {
        FavTreePopupView(
            file: Binding(
                get: { file.children?[index] ?? file },
                set: { newValue in
                    file.children?[index] = newValue
                }
            ),
            expandedFolders: $expandedFolders,
            isPresented: $isPresented
        )
        .environmentObject(appState)
    }

    // MARK: - Actions

    private func toggleExpansion() {
        guard isDirectoryType else { return }

        if isExpanded {
            expandedFolders.remove(file.pathStr)
        } else {
            expandedFolders.insert(file.pathStr)
        }

        log.debug("Toggled expansion for '\(file.nameStr)': now \(isExpanded ? "expanded" : "collapsed")")
    }

    private func handleFileTap() {
        if isDirectoryType {
            toggleExpansion()
        }

        log.info("Selected favorite: \(file.nameStr)")

        Task { @MainActor in
            appState.selectedDir.selectedFSEntity = file
            let targetPanel = appState.focusedPanel
            await appState.scanner.resetRefreshTimer(for: targetPanel)
            await appState.scanner.refreshFiles(currSide: targetPanel)
            isPresented = false
        }
    }

    private func autoExpandIfNeeded() {
        guard indentLevel <= 1 else { return }
        guard isDirectoryType else { return }
        guard let children = file.children, !children.isEmpty else { return }
        guard children.count <= 5, !isExpanded else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            expandedFolders.insert(file.pathStr)
            log.debug("Auto-expanded '\(file.nameStr)' with \(children.count) items")
        }
    }

    // MARK: - Icon Helpers

    private var iconName: String {
        let path = file.pathStr.lowercased()
        let name = file.nameStr

        // Network drives
        if name.hasPrefix("smb://") || name.hasPrefix("afp://") {
            return "server.rack"
        }

        // Volumes/Drives
        if path.hasPrefix("/volumes/") || path == "/volumes" {
            if path.contains("network") || name.hasPrefix("smb://") {
                return "network.badge.shield.half.filled"
            }
            return "externaldrive.fill"
        }

        // System folders
        if path.contains("/applications") { return "square.grid.3x3.fill" }
        if path.contains("/library") { return "building.columns.fill" }
        if path.contains("/system") { return "gearshape.2.fill" }
        if path.contains("/users") || path.contains("/home") { return "person.crop.circle.fill" }

        // User folders
        if path.contains("/desktop") { return "desktopcomputer" }
        if path.contains("/documents") { return "doc.text.fill" }
        if path.contains("/downloads") { return "arrow.down.circle.fill" }
        if path.contains("/movies") || path.contains("/videos") { return "film.fill" }
        if path.contains("/music") { return "music.note" }
        if path.contains("/pictures") || path.contains("/photos") { return "photo.fill" }

        // Default
        return isDirectoryType ? "folder.fill" : "doc.fill"
    }

    private var iconColor: Color {
        let path = file.pathStr.lowercased()
        let name = file.nameStr

        // Network - blue
        if name.hasPrefix("smb://") || name.hasPrefix("afp://") {
            return .blue
        }

        // Drives - purple
        if path.hasPrefix("/volumes/") || path == "/volumes" {
            return .purple
        }

        // System - red
        if path.contains("/system") || path.contains("/library") {
            return .red
        }

        // Applications - green
        if path.contains("/applications") {
            return .green
        }

        // User folders - orange
        if path.contains("/users") || path.contains("/home") {
            return .orange
        }

        // Directories - blue tint
        if isDirectoryType {
            return .blue.opacity(0.7)
        }

        // Files - gray
        return .secondary
    }

    // MARK: - Info Helpers

    private var fileInfoTooltip: String {
        var lines: [String] = []

        // Type
        if file.isSymbolicDirectory {
            lines.append("Symbolic Link (Directory)")
        } else if file.isDirectory {
            lines.append("Folder")
        } else {
            lines.append("File")
        }

        // Path
        lines.append("Path: \(file.pathStr)")

        // Children count
        if let children = file.children, !children.isEmpty {
            lines.append("Items: \(children.count)")
        }

        // Size
        if file.sizeInBytes > 0 {
            lines.append("Size: \(formattedSize(file.sizeInBytes))")
        }

        return lines.joined(separator: "\n")
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
