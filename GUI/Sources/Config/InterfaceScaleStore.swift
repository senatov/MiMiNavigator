// InterfaceScaleStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 02.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized UI scale factor for the entire application.
//   Provides a single multiplier (0.8–2.0) that all font sizes, icon sizes,
//   and row heights should reference. Persisted in ~/.mimi/defaults.json.

import SwiftUI

// MARK: - InterfaceScaleStore
@MainActor
@Observable
final class InterfaceScaleStore {
    static let shared = InterfaceScaleStore()
    // MARK: - Scale Range
    static let minScale: Double = 0.8
    static let maxScale: Double = 2.0
    static let defaultScale: Double = 1.0
    static let step: Double = 0.05
    // MARK: - State
    /// Current scale factor (1.0 = 100%)
    var scaleFactor: Double {
        didSet {
            let clamped = max(Self.minScale, min(scaleFactor, Self.maxScale))
            if scaleFactor != clamped { scaleFactor = clamped }
            MiMiDefaults.shared.set(clamped, forKey: storageKey)
            log.debug("[InterfaceScale] set to \(Int(clamped * 100))%")
        }
    }
    private let storageKey = "settings.interfaceScale"
    // MARK: - Init
    private init() {
        let saved = MiMiDefaults.shared.double(forKey: "settings.interfaceScale")
        if saved >= Self.minScale && saved <= Self.maxScale {
            self.scaleFactor = saved
        } else {
            self.scaleFactor = Self.defaultScale
        }
    }
    // MARK: - Convenience Scaled Values
    /// Scale a base CGFloat value by the current factor
    func scaled(_ base: CGFloat) -> CGFloat {
        base * CGFloat(scaleFactor)
    }
    /// Scale a base font size
    func scaledFontSize(_ base: CGFloat) -> CGFloat {
        max(9, base * CGFloat(scaleFactor))
    }
    /// Current percentage as Int (for display: "140%")
    var percentDisplay: Int {
        Int(round(scaleFactor * 100))
    }
    /// Reset to default scale
    func resetToDefault() {
        scaleFactor = Self.defaultScale
    }
}
