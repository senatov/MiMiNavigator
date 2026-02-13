// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView

import SwiftUI

// MARK: - Table Keyboard Navigation
/// Handles keyboard-based file selection and navigation
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    let onSelect: (CustomFile) -> Void
    let scrollProxy: ScrollViewProxy?
    
    // MARK: - Navigation Actions
    
    func moveUp() {
        guard !files.isEmpty else { return }
        let currentIndex = files.firstIndex { $0.id == selectedID.wrappedValue } ?? 0
        let newIndex = max(0, currentIndex - 1)
        selectAndScroll(at: newIndex, anchor: .center)
    }
    
    func moveDown() {
        guard !files.isEmpty else { return }
        let currentIndex = files.firstIndex { $0.id == selectedID.wrappedValue } ?? -1
        let newIndex = min(files.count - 1, currentIndex + 1)
        selectAndScroll(at: newIndex, anchor: .center)
    }
    
    func jumpToFirst() {
        guard let first = files.first else { return }
        selectAndScroll(file: first, anchor: .top)
    }
    
    func jumpToLast() {
        guard let last = files.last else { return }
        selectAndScroll(file: last, anchor: .bottom)
    }
    
    func scrollToSelection(_ id: CustomFile.ID?, anchor: UnitPoint = .center) {
        guard let id = id, let proxy = scrollProxy else { return }
        withAnimation(nil) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
    
    // MARK: - Private Helpers
    
    private func selectAndScroll(at index: Int, anchor: UnitPoint) {
        let file = files[index]
        selectAndScroll(file: file, anchor: anchor)
    }
    
    private func selectAndScroll(file: CustomFile, anchor: UnitPoint) {
        selectedID.wrappedValue = file.id
        onSelect(file)
        scrollToSelection(file.id, anchor: anchor)
        log.debug("[TableKeyboardNavigation] selected: \(file.nameStr)")
    }
}

// MARK: - Keyboard Shortcuts Layer
/// Hidden buttons providing keyboard shortcuts for table navigation
struct TableKeyboardShortcutsView: View {
    let isFocused: Bool
    let onPageUp: () -> Void
    let onPageDown: () -> Void
    let onHome: () -> Void
    let onEnd: () -> Void
    
    var body: some View {
        ZStack {
            shortcutButton(.pageUp, action: onPageUp)
            shortcutButton(.pageDown, action: onPageDown)
            shortcutButton(.home, action: onHome)
            shortcutButton(.end, action: onEnd)
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
    }
    
    private func shortcutButton(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        Button(action: { if isFocused { action() } }) { EmptyView() }
            .keyboardShortcut(key, modifiers: [])
    }
}
