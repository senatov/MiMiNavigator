//
//  DirIcon.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

// MARK: -
struct DirIcon: View {
    let item: EditablePathItem
    let pathStr: String

    var body: some View {
        let gradient = LinearGradient(
            colors: pathStr == item.pathStr
                ? [.blue.opacity(0.15), .blue.opacity(0.05)] : [.clear, .clear],
            startPoint: .top,
            endPoint: .bottom
        )

        return HStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(item.titleStr)
                .font(.callout)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(gradient)
                .shadow(color: .gray.opacity(pathStr == item.pathStr ? 0.3 : 0), radius: 5, x: 0, y: 2)
        )
    }
}
