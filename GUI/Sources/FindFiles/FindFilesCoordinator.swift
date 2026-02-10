// FindFilesCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinator for Find Files panel — manages visibility and lifecycle

import SwiftUI

// MARK: - Find Files Coordinator
/// Singleton coordinator that manages the Find Files panel lifecycle.
/// The panel is non-modal, so this coordinator simply tracks show/hide state.
@MainActor
@Observable
final class FindFilesCoordinator {
    static let shared = FindFilesCoordinator()

    /// Whether the Find Files panel is currently visible
    var isVisible: Bool = false

    /// The ViewModel instance — persists across show/hide for result preservation
    let viewModel = FindFilesViewModel()

    private init() {}

    // MARK: - Show / Hide

    /// Toggle Find Files panel visibility
    func toggle(searchPath: String? = nil) {
        if isVisible {
            hide()
        } else {
            show(searchPath: searchPath)
        }
    }

    /// Show the Find Files panel
    func show(searchPath: String? = nil) {
        if let path = searchPath {
            viewModel.configure(searchPath: path)
        }
        isVisible = true
        log.debug("[FindFiles] Panel shown")
    }

    /// Hide the Find Files panel (does NOT cancel search — it continues in background)
    func hide() {
        isVisible = false
        log.debug("[FindFiles] Panel hidden")
    }

    /// Close and cancel any running search
    func close() {
        viewModel.cancelSearch()
        isVisible = false
        log.debug("[FindFiles] Panel closed and search cancelled")
    }
}

// MARK: - View Modifier for embedding FindFiles panel
/// Attach this to the main DuoFilePanelView to overlay the non-modal Find Files panel
struct FindFilesPanelOverlay: ViewModifier {
    let coordinator: FindFilesCoordinator
    @Environment(AppState.self) var appState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if coordinator.isVisible {
                    FindFilesPanel(
                        viewModel: coordinator.viewModel,
                        onDismiss: { coordinator.close() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: coordinator.isVisible)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 42) // above bottom toolbar
                    .zIndex(100)
                }
            }
    }
}

extension View {
    /// Attach the Find Files non-modal panel overlay
    func findFilesOverlay(coordinator: FindFilesCoordinator) -> some View {
        modifier(FindFilesPanelOverlay(coordinator: coordinator))
    }
}
