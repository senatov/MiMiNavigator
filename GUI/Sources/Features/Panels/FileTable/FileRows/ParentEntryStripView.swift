// ParentEntryStripView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ".." parent-navigation strip with corner-triangle pebble button.
//   ◤ /ParentDir (N dirs)  — N respects Show Hidden setting.

import FileModelKit
import SwiftUI


// MARK: - ParentEntryStripView
struct ParentEntryStripView: View {
    let file: CustomFile
    let isSelected: Bool
    let parentURL: URL
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    private var label: String { "\(parentName)   (\(rowsCount) dirs)" }
    private let textColor = Color(#colorLiteral(red: 0.25, green: 0.25, blue: 0.27, alpha: 1))
    private let borderColor = Color(#colorLiteral(red: 0.55, green: 0.55, blue: 0.58, alpha: 1))
    private var pebbleActive: Bool { isSelected || isHovering }
    private var showHidden: Bool { UserPreferences.shared.snapshot.showHiddenFiles }

    private var parentName: String {
        parentURL.path == "/" ? "/Root" : parentURL.path
    }

    @State private var rowsCount: Int = 0
    @State private var isHovering = false


    private enum UI {
        static let stripHeight: CGFloat = 25
        static let pebbleWidth: CGFloat = 0.092
        static let pebbleHeight: CGFloat = 20
        static let textInset: CGFloat = 0.09
        static let borderHeight: CGFloat = 1.5
        static let shadowRadius: CGFloat = 3.0
        static let shadowY: CGFloat = -2.0
    }



    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.white
                pathLabel(geo: geo)
                pebbleButton(geo: geo)
                bottomBorder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UI.stripHeight)
        .zIndex(10)
        .onHover { h in withAnimation(.easeInOut(duration: 0.10)) { isHovering = h } }
        // Single tap on the strip itself = navigate to parent (same as double-click in TC)
        // The pebble button also triggers onDoubleClick directly
        .onTapGesture { onDoubleClick(file) }
        .task(id: "\(parentURL.path)-\(showHidden)") { await loadParentCount() }
    }


    // MARK: - Path Label
    private func pathLabel(geo: GeometryProxy) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .thin, design: .monospaced))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.leading, geo.size.width * UI.textInset)
    }


    // MARK: - Pebble Button (corner triangle)
    private func pebbleButton(geo: GeometryProxy) -> some View {
        let btnStyle = LiquidGlassButtonStyle(isHighlighted: pebbleActive)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: { onDoubleClick(file) }) {
                    Image(systemName: pebbleActive ? "arrowshape.turn.up.left.fill" : "arrowshape.turn.up.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(btnStyle.iconColor)
                        .rotationEffect(
                            .degrees(pebbleActive ? 45 : 0),
                            anchor: .center
                        )
                        .animation(
                            pebbleActive
                                ? .interpolatingSpring(stiffness: 180, damping: 6)
                                : .easeOut(duration: 0.15),
                            value: pebbleActive
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 1)
                        .offset(x: -3, y: -3)
                }
                .buttonStyle(btnStyle)
                .frame(width: geo.size.width * UI.pebbleWidth, height: UI.pebbleHeight)
                .clipped()
                Spacer()
            }
            Spacer()
        }
    }


    // MARK: - Bottom Border (prominent, with upward shadow)
    private var bottomBorder: some View {
        VStack {
            Spacer()
            borderColor
                .frame(height: UI.borderHeight)
                .shadow(color: .black.opacity(0.30), radius: UI.shadowRadius, x: 0, y: UI.shadowY)
        }
    }


    // MARK: - Load Parent Directory Count
    private func loadParentCount() async {
        let url = parentURL
        let hidden = showHidden
        let count = await Task.detached(priority: .utility) {
            Self.countSubdirectories(in: url, showHidden: hidden)
        }.value
        await MainActor.run { rowsCount = count }
    }


    // MARK: - Count Subdirectories (off MainActor)
    nonisolated static func countSubdirectories(in url: URL, showHidden: Bool) -> Int {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: []
        ) else { return 0 }
        return items.filter { item in
            guard let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey]) else { return false }
            let isDir = vals.isDirectory ?? false
            let isHid = vals.isHidden ?? false
            return isDir && (showHidden || !isHid)
        }.count
    }
}
