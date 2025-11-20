//
// StableBy.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -   A tiny wrapper that pins a stable identity for its content using the provided `key`. Useful when you need deterministic identity across re-renders without mutating state.
@MainActor
struct StableBy<Key: Hashable, Content: View>: View {
    private let key: Key
    private let content: () -> Content

    // MARK: - Body runs on main via struct-level @MainActor isolation
    public var body: some View {
        content().id(key)
    }

    // MARK: -
    init(_ key: Key, @ViewBuilder content: @escaping () -> Content) {
        self.key = key
        self.content = content
    }
}
