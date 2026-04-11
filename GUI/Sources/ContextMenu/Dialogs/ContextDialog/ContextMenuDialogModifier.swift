// ContextMenuDialogModifier.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Context Menu Dialog Modifier
/// Adds modal dialog support for context menu actions
struct ContextMenuDialogModifier: ViewModifier {
    let appState: AppState
    @Bindable var coordinator: CntMenuCoord

    func body(content: Content) -> some View {
        content
            .overlay {
                if coordinator.activeDialog != nil {
                    dialogOverlay
                }
            }
    }

    @ViewBuilder
    private var dialogOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap while processing
                    if !coordinator.isProcessing {
                        coordinator.dismissDialog()
                    }
                }

            // Dialog content
            if let dialog = coordinator.activeDialog {
                dialogContent(for: dialog)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: coordinator.activeDialog?.id)
    }

    @ViewBuilder
    private func dialogContent(for dialog: ActiveDialog) -> some View {
        switch dialog {
            case .deleteConfirmation,
                 .rename,
                 .pack,
                 .compress,
                 .createFolder,
                 .createLink,
                 .fileConflict,
                 .convertMedia:
                primaryDialogContent(for: dialog)
            case .error,
                 .success:
                alertDialogContent(for: dialog)
            case .batchCopyConfirmation,
                 .batchMoveConfirmation,
                 .batchDeleteConfirmation,
                 .batchPackConfirmation,
                 .batchProgress:
                batchDialogContent(for: dialog)
        }
    }
}


