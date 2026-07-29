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
    let displayParentPath: String
    let onSelect: (CustomFile) -> Void
    let onActivate: (CustomFile) -> Void
    let onDrop: (([CustomFile]) -> Bool)?
    let onDropTargetChange: ((Bool) -> Void)?
    let isExternalDropContact: Bool
    @State private var isHovering = false
    @State private var keyboardPulse = false
    @State private var isDropTargeted = false
    private var label: String { "Parent: \(displayParentPath)" }
    private var textColor: Color {
        isContactActive ? Color.white : isActive ? Self.activeContentColor : Color.black
    }
    private var iconColor: Color {
        isContactActive
            ? Color.white
            : isActive
            ? Self.activeContentColor
            : Color(#colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1))
    }
    private static let activeContentColor = Color(#colorLiteral(red: 0.02, green: 0.16, blue: 0.72, alpha: 1))
    private var isActive: Bool { isSelected || isHovering || isContactActive }
    private var isContactActive: Bool { isDropTargeted || isExternalDropContact }
    private enum UI {
        static let stripHeight: CGFloat = 25
        static let buttonInset: CGFloat = 1
        static let buttonHeight: CGFloat = 24
    }
    // MARK: - Initialization
    init(
        file: CustomFile,
        isSelected: Bool,
        parentURL: URL,
        displayParentPath: String? = nil,
        onSelect: @escaping (CustomFile) -> Void,
        onActivate: @escaping (CustomFile) -> Void,
        onDrop: (([CustomFile]) -> Bool)? = nil,
        onDropTargetChange: ((Bool) -> Void)? = nil,
        isExternalDropContact: Bool = false
    ) {
        self.file = file
        self.isSelected = isSelected
        self.parentURL = parentURL
        self.displayParentPath = displayParentPath ?? (parentURL.path == "/" ? "/Root" : parentURL.path)
        self.onSelect = onSelect
        self.onActivate = onActivate
        self.onDrop = onDrop
        self.onDropTargetChange = onDropTargetChange
        self.isExternalDropContact = isExternalDropContact
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
        .onChange(of: isSelected) { _, selected in
            triggerKeyboardPulse(selected)
        }
        .modifier(
            DropTargetModifier(
                isValidTarget: onDrop != nil,
                isDropTargeted: $isDropTargeted,
                onDrop: handleDrop,
                onTargetChange: handleDropTargetChange
            )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.68), value: isContactActive)
    }
    // MARK: - Strip Content
    private func stripContent(geo: GeometryProxy) -> some View {
        ZStack(alignment: .leading) {
            Color.white
            fullWidthButton(geo: geo)
        }
        .scaleEffect(isContactActive ? 1.025 : 1)
        .shadow(
            color: isContactActive
                ? Color(#colorLiteral(red: 0.12, green: 0.22, blue: 0.38, alpha: 0.38))
                : Color.clear,
            radius: isContactActive ? 5 : 0
        )
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
            .buttonStyle(
                ParentStripButtonStyle(
                    isHighlighted: isActive,
                    isDropContact: isContactActive,
                    keyboardPulse: keyboardPulse
                )
            )
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
            .font(.system(size: 10, weight: isContactActive ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
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
    // MARK: - Drop Handling
    private func handleDrop(_ files: [CustomFile]) -> Bool {
        guard let onDrop else { return false }
        return onDrop(files)
    }
    private func handleDropTargetChange(_ targeted: Bool) {
        isDropTargeted = targeted
        onDropTargetChange?(targeted)
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
