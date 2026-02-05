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
    @Bindable var coordinator: ContextMenuCoordinator
    
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
        case .deleteConfirmation(let files):
            DeleteConfirmationDialog(
                files: files,
                onConfirm: {
                    Task {
                        await coordinator.performDelete(files: files, appState: appState)
                    }
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .rename(let file):
            RenameDialog(
                file: file,
                onRename: { newName in
                    Task {
                        await coordinator.performRename(file: file, newName: newName, appState: appState)
                    }
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .pack(let files, let destination):
            PackDialog(
                files: files,
                destinationPath: destination,
                onPack: { archiveName, format, finalDestination in
                    Task {
                        await coordinator.performPack(
                            files: files,
                            archiveName: archiveName,
                            format: format,
                            destination: finalDestination,
                            appState: appState
                        )
                    }
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .createLink(let file, let destination):
            CreateLinkDialog(
                file: file,
                destinationPath: destination,
                onCreateLink: { linkName, linkType in
                    Task {
                        await coordinator.performCreateLink(
                            file: file,
                            linkName: linkName,
                            linkType: linkType,
                            destination: destination,
                            appState: appState
                        )
                    }
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .properties(let file):
            PropertiesDialog(
                file: file,
                onClose: {
                    coordinator.dismissDialog()
                }
            )
            
        case .fileConflict(let conflict, _):
            FileConflictDialog(
                conflict: conflict,
                onResolve: { resolution in
                    coordinator.resolveConflict(resolution)
                }
            )
            
        case .error(let title, let message):
            HIGAlertDialog(
                icon: "xmark.circle.fill",
                iconColor: .red,
                title: title,
                message: message,
                onDismiss: {
                    coordinator.dismissDialog()
                }
            )
            
        case .success(let title, let message):
            HIGAlertDialog(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: title,
                message: message,
                onDismiss: {
                    coordinator.dismissDialog()
                }
            )
            
        // MARK: - Batch Operation Dialogs
            
        case .batchCopyConfirmation(let files, let destination, let sourcePanel):
            BatchConfirmationDialog(
                operationType: .copy,
                files: files,
                destination: destination,
                onConfirm: {
                    coordinator.dismissDialog()
                    BatchOperationCoordinator.shared.executeCopy(
                        files: files,
                        destination: destination,
                        sourcePanel: sourcePanel,
                        appState: appState
                    )
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .batchMoveConfirmation(let files, let destination, let sourcePanel):
            BatchConfirmationDialog(
                operationType: .move,
                files: files,
                destination: destination,
                onConfirm: {
                    coordinator.dismissDialog()
                    BatchOperationCoordinator.shared.executeMove(
                        files: files,
                        destination: destination,
                        sourcePanel: sourcePanel,
                        appState: appState
                    )
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .batchDeleteConfirmation(let files, let sourcePanel):
            BatchConfirmationDialog(
                operationType: .delete,
                files: files,
                destination: nil,
                onConfirm: {
                    coordinator.dismissDialog()
                    BatchOperationCoordinator.shared.executeDelete(
                        files: files,
                        sourcePanel: sourcePanel,
                        appState: appState
                    )
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .batchPackConfirmation(let files, let destination, let sourcePanel):
            PackDialog(
                files: files,
                destinationPath: destination,
                onPack: { archiveName, format, finalDestination in
                    coordinator.dismissDialog()
                    BatchOperationCoordinator.shared.initiatePack(
                        appState: appState,
                        archiveName: archiveName,
                        format: format
                    )
                },
                onCancel: {
                    coordinator.dismissDialog()
                }
            )
            
        case .batchProgress(let state):
            BatchProgressDialog(
                state: state,
                onCancel: {
                    BatchOperationCoordinator.shared.cancelCurrentOperation()
                },
                onDismiss: {
                    coordinator.dismissDialog()
                    BatchOperationManager.shared.dismissProgressDialog()
                }
            )
        }
    }
}

// MARK: - HIG Alert Dialog (for Error/Success)
struct HIGAlertDialog: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // App icon with badge
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 28, height: 28)
                    )
                    .offset(x: 4, y: 4)
            }
            
            // Title
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            
            // Button
            HIGPrimaryButton(title: "OK", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .higDialogStyle()
    }
}

// MARK: - View Extension
extension View {
    func contextMenuDialogs(coordinator: ContextMenuCoordinator, appState: AppState) -> some View {
        modifier(ContextMenuDialogModifier(appState: appState, coordinator: coordinator))
    }
}
