// StableKeyView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.11.2024.
// Refactored: 27.01.2026
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: View wrapper that provides stable identity using a hashable key

import SwiftUI

// MARK: - Stable Key View
/// A wrapper view that pins stable identity for its content using a provided key.
/// Useful for preventing unnecessary re-renders when parent state changes,
/// while still allowing updates when the key actually changes.
///
/// Usage:
/// ```swift
/// StableKeyView(currentPath) {
///     ExpensiveView()
/// }
/// ```
@MainActor
struct StableKeyView<Key: Hashable, Content: View>: View {
    private let key: Key
    private let content: () -> Content

    var body: some View {
        content().id(key)
    }

    init(_ key: Key, @ViewBuilder content: @escaping () -> Content) {
        self.key = key
        self.content = content
    }
}

// MARK: - Deprecated Typealias (for backward compatibility)
typealias StableBy = StableKeyView
