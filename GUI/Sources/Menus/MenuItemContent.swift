//
// MenuItemContent.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct MenuItemContent: View {
    let title: String
    let shortcut: String?


    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack {
            Text(title)
            Spacer()
            if let shortcut = shortcut {
                Text(shortcut)
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
