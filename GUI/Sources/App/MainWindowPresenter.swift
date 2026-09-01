// MainWindowPresenter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.09.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bridges AppKit menu-bar actions to the SwiftUI main window scene.

import Foundation

// MARK: - MainWindowPresenter

@MainActor
final class MainWindowPresenter {
    static let shared = MainWindowPresenter()
    private var openWindowAction: (() -> Void)?
    private init() {}

    // MARK: - Install

    func install(openWindow: @escaping () -> Void) {
        let wasUnavailable = openWindowAction == nil
        openWindowAction = openWindow
        if wasUnavailable { log.info("[MainWindow] SwiftUI openWindow action installed") }
    }

    // MARK: - Open

    @discardableResult
    func open() -> Bool {
        guard let openWindowAction else {
            log.error("[MainWindow] SwiftUI openWindow action unavailable")
            return false
        }
        openWindowAction()
        log.info("[MainWindow] requested SwiftUI scene id='main'")
        return true
    }
}
