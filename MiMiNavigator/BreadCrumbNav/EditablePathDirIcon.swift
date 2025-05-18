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
struct EditablePathDirIcon: View, CustomStringConvertible {
    let item: EditablePathItem
    let pathStr: String

    var body: some View {
        let gradient = LinearGradient(
            colors: pathStr == item.pathStr
                ? [.blue.opacity(0.1), .blue.opacity(0.03)] : [.clear, .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        let cleanedTitleStr = item.titleStr.replacingOccurrences(of: "⋯", with: "")
        return HStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(cleanedTitleStr)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .onAppear {}
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(gradient)
                .shadow(color: .gray.opacity(pathStr == item.pathStr ? 0.3 : 0), radius: 5, x: 0, y: 2)
        )
    }

    nonisolated var description: String {
        "ConsoleCurrPath View"
    }

}
