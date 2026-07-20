// BackupConfirmationDialog.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import SwiftUI

// MARK: - Backup Confirmation Dialog
struct BackupConfirmationDialog: View {
    let files: [CustomFile]
    let assessment: BackupAssessment
    let archiveName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HIGDialogHeader(
                "Create large Temp-Backup?",
                subtitle: "The archive \"\(archiveName)\" will contain \(files.count) selected item(s)."
            )
            HStack(spacing: 10) {
                Image(systemName: "zipper.page")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(assessment.summary)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Large backups can take a long time and require additional free disk space.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            HIGDialogButtons(confirmTitle: "Create Temp-Backup", onCancel: onCancel, onConfirm: onConfirm)
        }
        .higDialogStyle()
    }
}
