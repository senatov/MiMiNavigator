//
//  ContextMenuDialogModifier+Builder.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Dialog Content Builders
extension ContextMenuDialogModifier {

    @ViewBuilder
    func primaryDialogContent(for dialog: ActiveDialog) -> some View {
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
            case .rename(let file, let panel):
                RenameDialog(
                    file: file,
                    onRename: { newName in
                        Task {
                            await coordinator.performRename(file: file, newName: newName, panel: panel, appState: appState)
                        }
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
            case .pack(let files, _, let sourcePanel):
                PackDialog(
                    mode: .pack,
                    files: files,
                    sourcePanel: sourcePanel,
                    onPack: { archiveName, format, finalDestination, deleteSource, compressionLevel, password in
                        Task {
                            await coordinator.performPack(
                                files: files,
                                archiveName: archiveName,
                                format: format,
                                destination: finalDestination,
                                deleteSource: deleteSource,
                                compressionLevel: compressionLevel,
                                password: password,
                                appState: appState
                            )
                        }
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
                .environment(appState)
            case .compress(let files, _, let sourcePanel):
                PackDialog(
                    mode: .compress,
                    files: files,
                    sourcePanel: sourcePanel,
                    onPack: { archiveName, format, finalDestination, deleteSource, compressionLevel, password in
                        Task {
                            await coordinator.performCompress(
                                files: files,
                                archiveName: archiveName,
                                destination: finalDestination,
                                moveToArchive: deleteSource,
                                compressionLevel: compressionLevel,
                                password: password,
                                appState: appState
                            )
                            await MainActor.run {
                                coordinator.dismissDialog()
                            }
                        }
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
                .environment(appState)
            case .createFolder(let parentURL):
                CreateFolderDialog(
                    parentURL: parentURL,
                    onCreateFolder: { folderName in
                        Task {
                            await coordinator.performCreateFolder(name: folderName, at: parentURL, appState: appState)
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
            case .fileConflict(let conflict, let remainingCount, _):
                FileConflictDialog(
                    conflict: conflict,
                    remainingCount: remainingCount,
                    onResolve: { decision in
                        coordinator.resolveConflict(decision)
                    }
                )
            default:
                EmptyView()
        }
    }

    @ViewBuilder
    func alertDialogContent(for dialog: ActiveDialog) -> some View {
        switch dialog {
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
            default:
                EmptyView()
        }
    }

    @ViewBuilder
    func batchDialogContent(for dialog: ActiveDialog) -> some View {
        switch dialog {
            case .batchCopyConfirmation(let files, let destination, let sourcePanel):
                BatchConfirmationDialog(
                    operationType: .copy,
                    files: files,
                    destination: destination,
                    onConfirm: {
                        coordinator.dismissDialog()
                        BatchOpsCoord.shared.executeCopy(
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
                        BatchOpsCoord.shared.executeMove(
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
                        BatchOpsCoord.shared.executeDelete(
                            files: files,
                            sourcePanel: sourcePanel,
                            appState: appState
                        )
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
            case .batchPackConfirmation(let files, _, let sourcePanel):
                PackDialog(
                    mode: .pack,
                    files: files,
                    sourcePanel: sourcePanel,
                    onPack: { archiveName, format, finalDestination, deleteSource, compressionLevel, password in
                        coordinator.dismissDialog()
                        BatchOpsCoord.shared.initiatePack(
                            appState: appState,
                            archiveName: archiveName,
                            format: format
                        )
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
                .environment(appState)
            case .batchProgress(let state):
                BatchProgressDialog(
                    state: state,
                    onCancel: {
                        BatchOpsCoord.shared.cancelCurrentOperation()
                    },
                    onDismiss: {
                        coordinator.dismissDialog()
                        BatchOperationManager.shared.dismissProgressDialog()
                    }
                )
            default:
                EmptyView()
        }
    }
}
