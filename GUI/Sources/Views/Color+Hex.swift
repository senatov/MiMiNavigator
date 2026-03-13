//
//  Color+Hex.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Color hex parsing/serialization and blending helpers.
//               Extracted from SettingsColorsPane.swift for single-responsibility.

import AppKit
import SwiftUI

// MARK: - Color+Hex
extension Color {
    // MARK: - init(hex:)
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double((val >>  0) & 0xFF) / 255
        )
    }

    // MARK: - toHex()
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    // MARK: - blended(with:fraction:)
    /// Blend with another color by fraction (0.0 = self, 1.0 = other)
    func blended(with other: Color, fraction: Double) -> Color {
        guard let c1 = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              let c2 = NSColor(other).usingColorSpace(.sRGB)?.cgColor.components,
              c1.count >= 3, c2.count >= 3 else { return self }
        let f = max(0, min(1, fraction))
        return Color(
            red:   c1[0] * (1 - f) + c2[0] * f,
            green: c1[1] * (1 - f) + c2[1] * f,
            blue:  c1[2] * (1 - f) + c2[2] * f
        )
    }
}
