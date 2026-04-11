//
//  ContextMenuNSMenuBuilder 2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import AppKit
import Foundation

@MainActor
enum ContextMenuNSMenuBuilder {

    static func fileMenu(
        optionHeld: Bool,
        onAction: @escaping (FileAction) -> Void,
        onBackgroundAction: ((PanelBackgroundAction) -> Void)? = nil,
        onMoreAction: (() -> Void)? = nil
    ) -> NSMenu {
        let menu = NSMenu()
        if let onMoreAction, !optionHeld {
            menu.addItem(
                item(
                    "For More 􀉒…",
                    icon: "ellipsis.circle",
                    shortcut: nil,
                    textColor: NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.46, alpha: 1.0)
                ) {
                    onMoreAction()
                }
            )
            menu.addItem(.separator())
        }
        menu.addItem(item(.open, onAction: onAction))
        menu.addItem(item(.openInNewTab, onAction: onAction))
        menu.addItem(item(.viewLister, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.cut, onAction: onAction))
        menu.addItem(item(.copy, onAction: onAction))
        menu.addItem(item(.copyAsPathname, onAction: onAction))
        menu.addItem(item(.paste, onAction: onAction, isEnabled: ClipboardManager.shared.hasContent))
        menu.addItem(item(.duplicate, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.compress, onAction: onAction))
        menu.addItem(item(.pack, onAction: onAction))
        menu.addItem(item(.share, onAction: onAction))
        menu.addItem(item(.revealInFinder, onAction: onAction))
        if optionHeld {
            menu.addItem(.separator())
            menu.addItem(item(.createLink, onAction: onAction))
            menu.addItem(item(.rename, onAction: onAction))
            menu.addItem(item(.delete, onAction: onAction))
            menu.addItem(item(.getInfo, onAction: onAction))
            menu.addItem(item(.addToFavorites, onAction: onAction))
            if let onBackgroundAction {
                menu.addItem(.separator())
                menu.addItem(item(.newFolder, onAction: onBackgroundAction))
                menu.addItem(item(.newFile, onAction: onBackgroundAction))
            }
        } else {
            appendHintIfNeeded(menu)
        }
        return menu
    }

    static func directoryMenu(
        optionHeld: Bool,
        onAction: @escaping (DirectoryAction) -> Void,
        onBackgroundAction: ((PanelBackgroundAction) -> Void)? = nil
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(.open, onAction: onAction))
        menu.addItem(item(.openInNewTab, onAction: onAction))
        menu.addItem(item(.openInFinder, onAction: onAction))
        menu.addItem(item(.openInTerminal, onAction: onAction))
        menu.addItem(item(.viewLister, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.cut, onAction: onAction))
        menu.addItem(item(.copy, onAction: onAction))
        menu.addItem(item(.copyAsPathname, onAction: onAction))
        menu.addItem(item(.paste, onAction: onAction, isEnabled: ClipboardManager.shared.hasContent))
        menu.addItem(item(.duplicate, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.compress, onAction: onAction))
        menu.addItem(item(.share, onAction: onAction))
        if optionHeld {
            menu.addItem(.separator())
            menu.addItem(item(.createLink, onAction: onAction))
            menu.addItem(item(.rename, onAction: onAction))
            menu.addItem(item(.delete, onAction: onAction))
        }
        menu.addItem(.separator())
        menu.addItem(item(.getInfo, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.openOnOtherPanel, onAction: onAction))
        menu.addItem(item(.addToFavorites, onAction: onAction))
        if !optionHeld {
            appendHintIfNeeded(menu)
        }
        if optionHeld, let onBackgroundAction {
            menu.addItem(.separator())
            menu.addItem(item(.newFolder, onAction: onBackgroundAction))
            menu.addItem(item(.newFile, onAction: onBackgroundAction))
        }
        return menu
    }

    static func multiSelectionMenu(
        optionHeld: Bool,
        onAction: @escaping (MultiSelectionAction) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(.cut, onAction: onAction))
        menu.addItem(item(.copy, onAction: onAction))
        menu.addItem(item(.copyAsPathname, onAction: onAction))
        menu.addItem(item(.paste, onAction: onAction, isEnabled: ClipboardManager.shared.hasContent))
        menu.addItem(.separator())
        menu.addItem(item(.compress, onAction: onAction))
        menu.addItem(item(.share, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.revealInFinder, onAction: onAction))
        if optionHeld {
            menu.addItem(.separator())
            menu.addItem(item(.delete, onAction: onAction))
        } else {
            appendHintIfNeeded(menu)
        }
        return menu
    }

    static func backgroundMenu(
        optionHeld: Bool,
        onAction: @escaping (PanelBackgroundAction) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(.goUp, onAction: onAction))
        menu.addItem(item(.goBack, onAction: onAction))
        menu.addItem(item(.goForward, onAction: onAction))
        menu.addItem(item(.refresh, onAction: onAction))
        menu.addItem(.separator())
        menu.addItem(item(.paste, onAction: onAction, isEnabled: ClipboardManager.shared.hasContent))
        menu.addItem(item(.openInFinder, onAction: onAction))
        menu.addItem(item(.openInTerminal, onAction: onAction))
        menu.addItem(item(.getInfo, onAction: onAction))
        if optionHeld {
            menu.addItem(.separator())
            menu.addItem(item(.newFolder, onAction: onAction))
            menu.addItem(item(.newFile, onAction: onAction))
            menu.addItem(item(.mirrorPath, onAction: onAction))
            menu.addItem(item(.openMarkedOnOtherPanel, onAction: onAction))
        } else {
            appendHintIfNeeded(menu)
        }
        return menu
    }

    private static func appendHintIfNeeded(_ menu: NSMenu) {
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "For More 􀉒…", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        hint.attributedTitle = NSAttributedString(
            string: "For More 􀉒…",
            attributes: [.foregroundColor: NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.46, alpha: 1.0)]
        )
        menu.addItem(hint)
    }

    private static func item(
        _ action: FileAction,
        onAction: @escaping (FileAction) -> Void,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let mi = item(action.title, icon: action.systemImage, shortcut: action.shortcutHint, textColor: nil) {
            onAction(action)
        }
        mi.isEnabled = isEnabled
        return mi
    }

    private static func item(
        _ action: DirectoryAction,
        onAction: @escaping (DirectoryAction) -> Void,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let mi = item(action.title, icon: action.systemImage, shortcut: action.shortcutHint, textColor: nil) {
            onAction(action)
        }
        mi.isEnabled = isEnabled
        return mi
    }

    private static func item(
        _ action: MultiSelectionAction,
        onAction: @escaping (MultiSelectionAction) -> Void,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let mi = item(action.title, icon: action.systemImage, shortcut: action.shortcutHint, textColor: nil) {
            onAction(action)
        }
        mi.isEnabled = isEnabled
        return mi
    }

    private static func item(
        _ action: PanelBackgroundAction,
        onAction: @escaping (PanelBackgroundAction) -> Void,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let mi = item(action.title, icon: action.systemImage, shortcut: action.shortcutHint, textColor: nil) {
            onAction(action)
        }
        mi.isEnabled = isEnabled
        return mi
    }

    private static func item(
        _ title: String,
        icon: String,
        shortcut: String?,
        textColor: NSColor? = nil,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let mi = CallbackMenuItem(title: title, callback: action)
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            mi.image = image
        }
        if let textColor {
            mi.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: textColor])
        }
        if let shortcut, !shortcut.isEmpty {
            mi.toolTip = shortcut
        }
        return mi
    }

    final class CallbackMenuItem: NSMenuItem {
        private let callback: () -> Void
        init(title: String, callback: @escaping () -> Void) {
            self.callback = callback
            super.init(title: title, action: #selector(runCallback), keyEquivalent: "")
            self.target = self
        }
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        @objc private func runCallback() {
            callback()
        }
    }
}
