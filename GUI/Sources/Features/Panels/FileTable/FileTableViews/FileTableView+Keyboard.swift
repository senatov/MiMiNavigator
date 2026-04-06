//
//  FileTableView+Keyboard.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

extension FileTableView {
    // MARK: - Keyboard Handling
    func handleUpArrow() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        keyboardNav.moveUp()
        return .handled
    }

    func handleDownArrow() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        keyboardNav.moveDown()
        return .handled
    }

    func handlePageUp() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        if pageNavThrottle.allow() {
            keyboardNav.pageUp()
        }
        return .handled
    }

    func handlePageDown() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        if pageNavThrottle.allow() {
            keyboardNav.pageDown()
        }
        return .handled
    }

    func handleHome() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        keyboardNav.jumpToFirst()
        return .handled
    }

    func handleEnd() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        keyboardNav.jumpToLast()
        return .handled
    }

    func handleEscape() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        appState.clearSelection(on: panelSide)
        selectedID = nil
        return .handled
    }

    // MARK: - Jump Commands
    var jumpToFirstPublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default
            .publisher(for: Notification.Name.jumpToFirst)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    var jumpToLastPublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default
            .publisher(for: Notification.Name.jumpToLast)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func handleJumpToFirst(_: Notification) {
        guard isFocused else { return }
        keyboardNav.jumpToFirst()
    }

    func handleJumpToLast(_: Notification) {
        guard isFocused else { return }
        keyboardNav.jumpToLast()
    }
}
