//
//  FileTableView+Keyboard.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Combine
import FileModelKit
import Foundation
import SwiftUI

extension FileTableView {
    // MARK: - Keyboard Handling
    func handleUpArrow() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        handleMoveUpCommand()
        return .handled
    }

    func handleMoveUpCommand() {
        appState.inlineRename.cancel()
        if handleTopEdgeParentNavigation() { return }
        keyboardNav.moveUp()
    }

    func handleDownArrow() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        appState.inlineRename.cancel()
        keyboardNav.moveDown()
        return .handled
    }

    func handlePageUp() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        handlePageUpCommand()
        return .handled
    }

    func handlePageUpCommand() {
        appState.inlineRename.cancel()
        if handleTopEdgeParentNavigation() { return }
        if pageNavThrottle.allow() {
            keyboardNav.pageUp()
        }
    }

    func handlePageDown() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        appState.inlineRename.cancel()
        if pageNavThrottle.allow() {
            keyboardNav.pageDown()
        }
        return .handled
    }

    func handleHome() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        appState.inlineRename.cancel()
        keyboardNav.jumpToFirst()
        return .handled
    }

    func handleEnd() -> KeyPress.Result {
        guard isFocused else { return .ignored }
        appState.inlineRename.cancel()
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

    // MARK: - Top Edge Parent Navigation
    private func handleTopEdgeParentNavigation() -> Bool {
        guard isAtTopEdge else {
            lastTopEdgeKeyPressAt = nil
            isParentStripHighlighted = false
            return false
        }
        let now = Date()
        let isSecondQuickPress = lastTopEdgeKeyPressAt.map { now.timeIntervalSince($0) <= 0.45 } ?? false
        lastTopEdgeKeyPressAt = now
        if isSecondQuickPress {
            activateParentFromTopEdge()
        } else {
            highlightParentFromTopEdge()
        }
        return true
    }

    private var isAtTopEdge: Bool {
        guard currentPanelPath != "/" else { return false }
        guard !cachedSortedRows.isEmpty else { return true }
        guard let selectedID else { return true }
        return cachedIndexByID[selectedID] == 0
    }

    private func highlightParentFromTopEdge() {
        let parentFile = CustomFile.parentLink(from: currentPanelPath)
        selectedID = nil
        isParentStripHighlighted = true
        onSelect(parentFile)
        log.debug("[Nav] top edge parent highlighted panel=\(panelSide.rawValue) path='\(parentFile.urlValue.path)'")
    }

    private func activateParentFromTopEdge() {
        let parentFile = CustomFile.parentLink(from: currentPanelPath)
        selectedID = nil
        isParentStripHighlighted = false
        log.info("[Nav] top edge parent activated panel=\(panelSide.rawValue) path='\(parentFile.urlValue.path)'")
        onDoubleClick(parentFile)
    }
}
