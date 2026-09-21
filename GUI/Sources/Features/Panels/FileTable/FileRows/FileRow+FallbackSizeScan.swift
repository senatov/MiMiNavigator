//
//  FileRow+FallbackSizeScan.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Fallback Size Scan
extension FileRow {

    // MARK: - Fallback directory scan
    func fallbackDirectoryScanAsync(url: URL) async -> Int64 {
        let target = resolvedDirectorySizeTargetURL(from: url)
        let cancellation = DirectorySizeCancellationState()
        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                DirectorySizeNativeCalculator.fallbackDirectorySize(target, cancellation: cancellation)
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }
}
