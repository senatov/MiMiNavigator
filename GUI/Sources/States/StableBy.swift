// StableBy.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Wrapper that pins stable identity for content using the provided key
// Useful for preventing unnecessary re-renders when parent state changes
@MainActor
struct StableBy<Key: Hashable, Content: View>: View {
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
