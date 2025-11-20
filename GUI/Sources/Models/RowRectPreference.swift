//
// RowRectPref.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - RowRectPreference
struct RowRectPreference: PreferenceKey {
    static var defaultValue: [CustomFile.ID: CGRect] { [:] }

    // MARK: -
    static func reduce(value: inout [CustomFile.ID: CGRect], nextValue: () -> [CustomFile.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in
            // keep the new value if the same key appears
            newValue
        })
    }
}
