// HIGPicker.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: macOS Settings style picker — .menu style.

import SwiftUI

// MARK: - HIGPicker
/// Matches macOS Settings "External Editor" / "Shell" picker.
struct HIGPicker<T: Hashable & CustomStringConvertible, Content: View>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    var displayName: (T) -> String = { $0.description }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(displayName(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
