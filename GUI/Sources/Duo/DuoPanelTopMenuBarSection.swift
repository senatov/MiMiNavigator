//
// DuoPanelTopMenuBarSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Top menu bar section for dual-panel view
struct DuoPanelTopMenuBarSection: View {
    private enum Layout {
        static let topMenuPadding: CGFloat = 8
    }
    
    var body: some View {
        TopMenuBarView()
            .frame(maxWidth: .infinity)
            .padding(Layout.topMenuPadding)
            .fixedSize(horizontal: false, vertical: true)
    }
}
