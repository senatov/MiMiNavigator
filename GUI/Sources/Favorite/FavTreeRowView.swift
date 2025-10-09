//
//  FavTreeRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import SwiftUI

struct FavTreeRowView: View {
    let file: CustomFile
    let isExpanded: Bool
    let toggle: () -> Void
    let select: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: file.isDirectory ? "chevron.right" : "doc.text")
                .rotationEffect(.degrees(file.isDirectory && isExpanded ? 90 : 0))
                .foregroundStyle(file.isDirectory ? .accent : .secondary)
                .frame(width: 14)
                .contentShape(Rectangle())
                .onTapGesture { if file.isDirectory { toggle() } }

            Text(file.nameStr)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .onTapGesture { select() }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isExpanded ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }
}