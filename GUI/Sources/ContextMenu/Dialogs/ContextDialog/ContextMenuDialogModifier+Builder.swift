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
            case .deleteConfirmation(let files, let sourcePanel):
                DeleteConfirmationDialog(
                    files: files,
                    onConfirm: { inBackground in
                        if inBackground { coordinator.dismissDialog() }
                        Task {
                            await ProgressPanel.runFileOperation(inBackground: inBackground, operation: .delete) {
                                await coordinator.performDelete(files: files, sourcePanel: sourcePanel, appState: appState)
                            }
                        }
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
            case .pack, .compress:
                EmptyView()
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
            case .createFile(let parentURL):
                CreateFileDialog(
                    parentURL: parentURL,
                    onCreateFile: { fileName in
                        Task {
                            await coordinator.performCreateFile(name: fileName, at: parentURL, appState: appState)
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
            case .backupConfirmation(let files, let assessment, let archiveURL, let sourcePanel):
                BackupConfirmationDialog(
                    files: files,
                    assessment: assessment,
                    archiveName: archiveURL.lastPathComponent,
                    onConfirm: {
                        coordinator.dismissDialog()
                        Task {
                            await coordinator.performBackup(
                                files: files,
                                archiveURL: archiveURL,
                                sourcePanel: sourcePanel,
                                showsProgress: true,
                                appState: appState
                            )
                        }
                    },
                    onCancel: { coordinator.dismissDialog() }
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
                    onConfirm: { inBackground in
                        coordinator.dismissDialog()
                        BatchOpsCoord.shared.executeCopy(
                            files: files,
                            destination: destination,
                            sourcePanel: sourcePanel,
                            appState: appState,
                            inBackground: inBackground
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
                    onConfirm: { inBackground in
                        coordinator.dismissDialog()
                        BatchOpsCoord.shared.executeMove(
                            files: files,
                            destination: destination,
                            sourcePanel: sourcePanel,
                            appState: appState,
                            inBackground: inBackground
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
                    onConfirm: { inBackground in
                        coordinator.dismissDialog()
                        BatchOpsCoord.shared.executeDelete(
                            files: files,
                            sourcePanel: sourcePanel,
                            appState: appState,
                            inBackground: inBackground
                        )
                    },
                    onCancel: {
                        coordinator.dismissDialog()
                    }
                )
            case .batchPackConfirmation:
                EmptyView()
            default:
                EmptyView()
        }
    }
}
