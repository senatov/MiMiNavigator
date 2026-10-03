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
    @Binding var isFinderSidebarVisible: Bool

    var body: some View {
        TopMenuBarView(isFinderSidebarVisible: $isFinderSidebarVisible)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}
