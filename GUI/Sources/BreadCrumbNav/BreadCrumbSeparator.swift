//
//  BreadCrumbSeparator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
//  Description: Stable slash separator for breadcrumb segments.
//

import SwiftUI

// MARK: - BreadCrumb Separator
struct BreadCrumbSeparator: View {
    let fontSize: CGFloat

    // MARK: - Body
    var body: some View {
        Text("/")
            .font(.system(size: (fontSize * 2).rounded() / 2, weight: .regular, design: .default))
            .foregroundStyle(.secondary.opacity(0.76))
            .frame(width: max(7, (fontSize * 0.58).rounded()), height: 22)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
