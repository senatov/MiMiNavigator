    // TopMenuMetadata.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 01.06.2025.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: Menu item metadata — real actions where implemented, stub popups elsewhere.
    //   Items with HotKeyAction use live shortcut display from HotKeyStore.

    import AppKit
    import Foundation

    // MARK: - Stub popup helper
    @MainActor
func stub(_ title: String) -> @MainActor @Sendable () -> Void {
        {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = "This feature is not yet implemented."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

// Menu categories split into:
// - TopMenuFilesMark.swift  (Files, Mark)
// - TopMenuCommands.swift   (Commands, Net, Show)
// - TopMenuConfig.swift     (Configuration, Start, Help)
