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
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.68, y: size.height * 0.22))
            path.addLine(to: CGPoint(x: size.width * 0.32, y: size.height * 0.78))
            context.stroke(path, with: .color(.secondary.opacity(0.82)), lineWidth: 1.15)
        }
        .frame(width: max(7, fontSize * 0.58), height: 22)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
