// ParentEntryStripView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Fixed parent-navigation strip above the file table.

import FileModelKit
import SwiftUI

// MARK: - ParentEntryStripView
struct ParentEntryStripView: View {
    static let rowHeight: CGFloat = 25
    let file: CustomFile
    let isSelected: Bool
    let parentURL: URL
    let onSelect: (CustomFile) -> Void
    let onActivate: (CustomFile) -> Void
    @State private var rowsCount: Int = 0
    @State private var isHovering = false
    @State private var keyboardPulse = false
    private var label: String { "\(parentName)   (\(rowsCount) dirs)" }
    private var textColor: Color {
        isActive ? Color(#colorLiteral(red: 1, green: 0.92, blue: 0.05, alpha: 1)) : Color.black
    }
    private var iconColor: Color {
        isActive
            ? Color(#colorLiteral(red: 1, green: 0.88, blue: 0.04, alpha: 1))
            : Color(#colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1))
    }
    private let borderColor = Color(#colorLiteral(red: 0.55, green: 0.55, blue: 0.58, alpha: 1))
    private var isActive: Bool { isSelected || isHovering }
    private var showHidden: Bool { UserPreferences.shared.snapshot.showHiddenFiles }
    private var parentName: String { parentURL.path == "/" ? "/Root" : parentURL.path }
    private var countTaskID: String { "\(parentURL.path)-\(showHidden)" }
    private enum UI {
        static let stripHeight: CGFloat = 25
        static let buttonInset: CGFloat = 1
        static let buttonHeight: CGFloat = 24
        static let borderHeight: CGFloat = 1.5
        static let shadowRadius: CGFloat = 3.0
        static let shadowY: CGFloat = -2.0
    }
    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            stripContent(geo: geo)
        }
        .frame(maxWidth: .infinity)
        .frame(height: UI.stripHeight)
        .contentShape(Rectangle())
        .zIndex(10)
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    activateParentNavigation()
                }
        )
        .task(id: countTaskID) {
            await loadParentCount()
        }
        .onChange(of: isSelected) { _, selected in
            triggerKeyboardPulse(selected)
        }
    }
    // MARK: - Strip Content
    private func stripContent(geo: GeometryProxy) -> some View {
        ZStack(alignment: .leading) {
            Color.white
            fullWidthButton(geo: geo)
            bottomBorder
        }
    }
    // MARK: - Full Width Button
    private func fullWidthButton(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Button(action: activateParentNavigation) {
                HStack(spacing: 6) {
                    parentArrowIcon
                    parentLabel
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(ParentStripButtonStyle(isHighlighted: isActive, keyboardPulse: keyboardPulse))
            .frame(width: max(0, geo.size.width - UI.buttonInset * 2), height: UI.buttonHeight)
            .overlay(ParentStripCursorView(isHovering: $isHovering))
            .padding(.horizontal, UI.buttonInset)
            Spacer()
        }
    }
    // MARK: - Parent Arrow Icon
    private var parentArrowIcon: some View {
        Image(systemName: isActive ? "arrowshape.turn.up.left.fill" : "arrowshape.turn.up.left")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(iconColor)
            .rotationEffect(.degrees(isActive ? 45 : 0), anchor: .center)
            .animation(
                isActive
                    ? .interpolatingSpring(stiffness: 180, damping: 6)
                    : .easeOut(duration: 0.15),
                value: isActive
            )
    }
    // MARK: - Parent Label
    private var parentLabel: some View {
        Text(label)
            .font(.system(size: 10, weight: .thin, design: .monospaced))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
    }
    // MARK: - Bottom Border
    private var bottomBorder: some View {
        VStack {
            Spacer()
            borderColor
                .frame(height: UI.borderHeight)
                .shadow(color: .black.opacity(0.30), radius: UI.shadowRadius, x: 0, y: UI.shadowY)
        }
    }
    // MARK: - Parent Navigation
    private func activateParentNavigation() {
        log.debug("[ParentEntryStripView] activate parent path=\(parentURL.path)")
        onSelect(file)
        Task { @MainActor in
            log.debug("[ParentEntryStripView] navigate parent path=\(parentURL.path)")
            onActivate(file)
        }
    }
    // MARK: - Load Parent Directory Count
    private func loadParentCount() async {
        let url = parentURL
        let hidden = showHidden
        let count = await Task.detached(priority: .utility) {
            Self.countSubdirectories(in: url, showHidden: hidden)
        }.value
        await updateRowsCount(count)
    }
    // MARK: - Update Rows Count
    private func updateRowsCount(_ count: Int) async {
        let newCount = count
        DispatchQueue.main.async {
            guard rowsCount != newCount else { return }
            rowsCount = newCount
        }
    }
    // MARK: - Count Subdirectories
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
    // MARK: - Keyboard Pulse
    private func triggerKeyboardPulse(_ selected: Bool) {
        guard selected else {
            keyboardPulse = false
            return
        }
        keyboardPulse = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(18))
            keyboardPulse = true
            try? await Task.sleep(for: .milliseconds(180))
            keyboardPulse = false
        }
    }
}
