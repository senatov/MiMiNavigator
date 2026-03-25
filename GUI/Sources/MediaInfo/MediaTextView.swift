//
//  MediaTextView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


import AppKit
import AVFoundation
import UniformTypeIdentifiers
import SwiftyBeaver

// MARK: - MediaTextView
final class MediaTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c",
           selectedRange().length == 0 {
            NotificationCenter.default.post(name: .init("MediaInfoCopyAll"), object: nil)
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 123 {
            NotificationCenter.default.post(name: .init("MediaInfoPrev"), object: nil)
            return true
        }
        if event.keyCode == 124 {
            NotificationCenter.default.post(name: .init("MediaInfoNext"), object: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}