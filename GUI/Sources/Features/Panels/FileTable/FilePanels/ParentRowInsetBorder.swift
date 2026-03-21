//
//  ParentRowInsetBorder.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import SwiftUI

// MARK: - ParentRowInsetBorder
private struct ParentRowInsetBorder: View {

    let borderColor: Color
    let borderWidth: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(borderColor.opacity(0.55), lineWidth: borderWidth)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(borderColor.opacity(0.35))
                    .frame(height: borderWidth)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(height: max(borderWidth * 0.6, 0.5))
            }
        }
    }
}
