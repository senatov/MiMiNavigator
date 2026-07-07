// StableKeyView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.11.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: View wrapper that provides stable identity using a hashable key

import SwiftUI

// MARK: - Stable Key View
/// Assigns explicit SwiftUI identity to content and recreates it when the key changes.
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
