//
//  AppManagedMountCleanupScheduler.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
//  Description: Periodic cleanup for app-managed network mount directories.
//

import Foundation

// MARK: - App Managed Mount Cleanup Scheduler
@MainActor
enum AppManagedMountCleanupScheduler {
    private static var task: Task<Void, Never>?

    // MARK: - Start
    static func start() {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                await AppState.cleanupStaleAppManagedMounts()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }
}
