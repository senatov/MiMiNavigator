// ProgressReporting.swift
// MiMiNavigator
//
// Created by Claude on 19.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Universal progress reporting protocol — archive, file ops, network ops all conform

import Foundation

// MARK: - Progress Reporting Protocol

/// Any long-running operation can report progress thru this protocol.
/// ProgressPanel observes conforming objects to show status in HUD.
@MainActor
protocol ProgressReporting: AnyObject {
    /// Short operation title, e.g. "Packing archive.zip"
    var progressTitle: String { get }
    /// Current status line, e.g. "Compressing file 3/12…"
    var progressStatus: String { get }
    /// SF Symbol icon name
    var progressIcon: String { get }
    /// 0.0…1.0 or nil if indeterminate
    var fractionCompleted: Double? { get }
    /// Whether user requested cancel
    var isCancelled: Bool { get }
    /// Request cancellation — implementation should stop ASAP & rollback
    func cancel()
}
