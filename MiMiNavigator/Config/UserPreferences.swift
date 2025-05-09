//  UserPreferences.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//

import Foundation
import SwiftUI
import SwiftyBeaver

struct UserPreferences {
    static let shared = UserPreferences()
    // Keys for storing window and UI state
    private let mimiWidthKey = "windowWidthMimi0"
    private let mimiHeightKey = "windowHeightMiMi0"
    private let mimiLeftPanelWidthKey = "leftPanelWidthMiMi0"
    private let mimiMenuStateKey = "menuStatemiMi0"
    private let mimiWindowPosXKey = "windowPosXMiMi0"
    private let mimiWindowPosYKey = "windowPosYMiMi0"

    private init() {}

    // MARK: -
    func saveWindowSize(width: CGFloat, height: CGFloat) {
        log.debug(#function)
        log.debug("Saving window size - Width: \(width), Height: \(height)")
        UserDefaults.standard.set(width, forKey: mimiWidthKey)
        UserDefaults.standard.set(height, forKey: mimiHeightKey)
    }

    // MARK: -
    func saveWindowPosition(x: CGFloat, y: CGFloat) {
        log.debug(#function)
        log.debug("Saving window position - X: \(x), Y: \(y)")
        UserDefaults.standard.set(x, forKey: mimiWindowPosXKey)
        UserDefaults.standard.set(y, forKey: mimiWindowPosYKey)
    }

    func saveLeftPanelWidth(_ width: CGFloat) {
        log.debug(#function)
        log.debug("Saving left panel width - Width: \(width)")
        UserDefaults.standard.set(width, forKey: mimiLeftPanelWidthKey)
    }

    // MARK: -
    func restoreWindowSize() -> CGSize {
        log.debug(#function)
        let width = UserDefaults.standard.object(forKey: mimiWidthKey) as? CGFloat ?? 800
        let height = UserDefaults.standard.object(forKey: mimiHeightKey) as? CGFloat ?? 600
        log.debug("Restoring window size - Width: \(width), Height: \(height)")
        return CGSize(width: width, height: height)
    }
    // MARK: -
    func restoreWindowPosition(screenSize: CGSize) -> CGPoint {
        log.debug(#function)
        // Default to the center of the screen if no saved position is found
        let defaultX = (screenSize.width - 800) / 2  // Assuming default width of 800
        let defaultY = (screenSize.height - 600) / 2  // Assuming default height of 600

        let x = UserDefaults.standard.object(forKey: mimiWindowPosXKey) as? CGFloat ?? defaultX
        let y = UserDefaults.standard.object(forKey: mimiWindowPosYKey) as? CGFloat ?? defaultY

        log.debug("Restoring window position - X: \(x), Y: \(y) (Default if not saved - X: \(defaultX), Y: \(defaultY))")
        return CGPoint(x: x, y: y)
    }

    // MARK: -
    func restoreLeftPanelWidth() -> CGFloat {
        log.debug(#function)
        let width = UserDefaults.standard.object(forKey: mimiLeftPanelWidthKey) as? CGFloat ?? 300
        log.debug("Restoring left panel width - Width: \(width)")
        return width
    }
}
