// ArchiveToolInstallAlert.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Install prompt for optional archive tools.

import ExternalToolsKit

// MARK: - Archive Tool Install Alert
@MainActor
enum ArchiveToolInstallAlert {

    // MARK: - Prompt Archive Tool Install
    static func promptInstall(useUnar: Bool = false, reason: String) {
        Task {
            let tool = useUnar ? ExternalToolCatalog.unar : ExternalToolCatalog.sevenZip
            let report = await ExternalToolDoctor.shared.diagnose(tool)
            _ = await ExternalToolDoctor.shared.promptRepair(
                tool: tool,
                report: report,
                context: reason
            )
        }
    }

}
