// ProgressPanel+StyledLog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Styled log rows for ProgressPanel.

import AppKit

// MARK: - Styled Log

extension ProgressPanel {
    // MARK: - Append Key Value Log
    func appendKeyValueLog(_ key: String, value: String) {
        let appearance = ProgressPanelAppearance.shared
        let entry = NSMutableAttributedString(
            string: "\(key): ",
            attributes: [
                .font: appearance.logFont,
                .foregroundColor: NSColor.labelColor,
            ])
        entry.append(
            NSAttributedString(
                string: value,
                attributes: [
                    .font: NSFontManager.shared.convert(appearance.logFont, toHaveTrait: .boldFontMask),
                    .foregroundColor: appearance.logColor,
                ]))
        appendAttributedLog(entry)
    }
}
