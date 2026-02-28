//
// HelpPopup.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -

struct HelpPopup: View {
    let text: String
    @State private var colorStore = ColorThemeStore.shared
    var body: some View {
        log.info(#function)
        return Text(text)
            .font(.system(size: 12))
            .foregroundStyle(ColorThemeStore.shared.activeTheme.accentColor)
            .padding(8)
            .background(colorStore.activeTheme.selectionInactive)
            .clipShape(.rect(cornerRadius: 6))
            .frame(width: 200)
    }
}
