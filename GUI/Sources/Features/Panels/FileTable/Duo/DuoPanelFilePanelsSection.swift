//
// DuoPanelFilePanelsSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import FileModelKit

/// File panels container section with geometry management
struct DuoPanelFilePanelsSection: View {
    @Binding var leftPanelWidth: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let fetchFiles: @Sendable @concurrent (PanelSide) async -> Void
    
    var body: some View {
        PanelsRowView(
            leftPanelWidth: $leftPanelWidth,
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            fetchFiles: fetchFiles
        )
    }
}
