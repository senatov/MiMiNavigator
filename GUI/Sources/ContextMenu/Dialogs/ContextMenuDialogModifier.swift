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
            Color.black.opacity(0.4)
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
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.activeDialog?.id)
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
                onPack: { archiveName, format in
                    Task {
                        await coordinator.performPack(
                            files: files,
                            archiveName: archiveName,
                            format: format,
                            destination: destination,
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
            
        case .error(let title, let message):
            ErrorDialog(
                title: title,
                message: message,
                onDismiss: {
                    coordinator.dismissDialog()
                }
            )
            
        case .success(let title, let message):
            SuccessDialog(
                title: title,
                message: message,
                onDismiss: {
                    coordinator.dismissDialog()
                }
            )
        }
    }
}

// MARK: - Error Dialog
struct ErrorDialog: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .padding(.top, 8)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                    Text("OK")
                }
                .frame(minWidth: 100)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovering ? Color.blue.opacity(0.9) : Color.blue.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(minWidth: 350, maxWidth: 450)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Success Dialog
struct SuccessDialog: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .padding(.top, 8)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                    Text("OK")
                }
                .frame(minWidth: 100)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovering ? Color.green.opacity(0.9) : Color.green.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(minWidth: 350, maxWidth: 450)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - View Extension
extension View {
    func contextMenuDialogs(coordinator: ContextMenuCoordinator, appState: AppState) -> some View {
        modifier(ContextMenuDialogModifier(appState: appState, coordinator: coordinator))
    }
}
