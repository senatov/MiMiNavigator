//
//  UserPreferences.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//

import Foundation
import SwiftUI

struct UserPreferences {
    static let shared = UserPreferences()

    // Keys for storing window and UI state
    private let windowWidthKey = "windowWidth"
    private let windowHeightKey = "windowHeight"
    private let leftPanelWidthKey = "leftPanelWidth"
    private let menuStateKey = "menuState"

    private init() {}

    // Save preferences
    func saveWindowSize(width: CGFloat, height: CGFloat) {
        UserDefaults.standard.set(width, forKey: windowWidthKey)
        UserDefaults.standard.set(height, forKey: windowHeightKey)
    }

    func saveLeftPanelWidth(_ width: CGFloat) {
        UserDefaults.standard.set(width, forKey: leftPanelWidthKey)
    }

    func saveMenuState(isOpen: Bool) {
        UserDefaults.standard.set(isOpen, forKey: menuStateKey)
    }

    // Restore preferences
    func restoreWindowSize() -> CGSize {
        let width = UserDefaults.standard.object(forKey: windowWidthKey) as? CGFloat ?? 800
        let height = UserDefaults.standard.object(forKey: windowHeightKey) as? CGFloat ?? 600
        return CGSize(width: width, height: height)
    }

    func restoreLeftPanelWidth() -> CGFloat {
        return UserDefaults.standard.object(forKey: leftPanelWidthKey) as? CGFloat ?? 300
    }

    func restoreMenuState() -> Bool {
        return UserDefaults.standard.bool(forKey: menuStateKey)
    }
}
