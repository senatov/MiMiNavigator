//
//  FileRow+AppManagedMountSize.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - App Managed Mount Size
extension FileRow {

    // MARK: - Metadata task
    func runAppManagedMountMetadataTask(for url: URL) async {
        let sizeResolved = file.cachedShallowSize != nil || file.cachedDirectorySize == DirectorySizeService.unavailableSize
        if file.cachedChildCount != nil && sizeResolved {
            file.sizeCalculationStarted = false
            return
        }
        file.sizeCalculationStarted = true
        let targetURL = resolvedDirectorySizeTargetURL(from: url)
        guard let metadata = await AppManagedMountMetadataProbe.partialMetadata(for: targetURL) else {
            log.debug("[FileRow] app-managed network mount metadata skipped for '\(file.nameStr)' path='\(targetURL.path)'")
            file.cachedDirectorySize = DirectorySizeService.unavailableSize
            file.sizeIsExact = false
            file.sizeCalculationStarted = false
            return
        }
        if let childCount = metadata.childCount {
            file.cachedChildCount = childCount
        }
        file.cachedShallowSize = metadata.partialSize
        file.cachedDirectorySize = metadata.partialSize == nil ? DirectorySizeService.unavailableSize : nil
        file.sizeIsExact = false
        file.sizeCalculationStarted = false
        appState.bumpFilesVersion(for: panelSide)
    }
}
