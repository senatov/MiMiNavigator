//
//  ContextMenuDialogModifier+View.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - View Extension
extension View {
    func contextMenuDialogs(coordinator: CntMenuCoord, appState: AppState) -> some View {
        modifier(ContextMenuDialogModifier(appState: appState, coordinator: coordinator))
    }
}
