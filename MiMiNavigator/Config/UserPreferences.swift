//  UserPreferences.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//

import Foundation
import SwiftUI
import SwiftyBeaver

///  -
struct UserPreferences {
    static let shared = UserPreferences()
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
        let width = UserDefaults.standard.object(forKey: mimiWidthKey) as? CGFloat ?? 1600
        let height = UserDefaults.standard.object(forKey: mimiHeightKey) as? CGFloat ?? 1200
        log.debug("Restoring window size - Width: \(width), Height: \(height)")
        return CGSize(width: width, height: height)
    }
    // MARK: -
    func restoreWindowPosition(screenSize: CGSize) -> CGPoint {
        log.debug(#function)
        // Default to the center of the screen if no saved position is found
        let defaultX = (screenSize.width - 1600) / 2
        let defaultY = (screenSize.height - 1200) / 2

        let x = UserDefaults.standard.object(forKey: mimiWindowPosXKey) as? CGFloat ?? defaultX
        let y = UserDefaults.standard.object(forKey: mimiWindowPosYKey) as? CGFloat ?? defaultY

        log.debug(
            "Restoring window position - X: \(x), Y: \(y) (Default if not saved - X: \(defaultX), Y: \(defaultY))"
        )
        return CGPoint(x: x, y: y)
    }

    // MARK: -
    func restoreLeftPanelWidth() -> CGFloat {
        log.debug(#function)
        // Restore saved width or use default left panel width (320) if not set
        let width = UserDefaults.standard.object(forKey: mimiLeftPanelWidthKey) as? CGFloat ?? 320
        log.debug("Restoring left panel width - Width: \(width)")
        return width
    }
    // MARK: -
    func saveMenuState(isOpen: Bool) {
        log.debug(#function)
        log.debug("Saving menu state - isOpen: \(isOpen)")
        UserDefaults.standard.set(isOpen, forKey: mimiMenuStateKey)
    }

    func restoreMenuState() -> Bool {
        log.debug(#function)
        let state = UserDefaults.standard.object(forKey: mimiMenuStateKey) as? Bool ?? true
        log.debug("Restoring menu state - isOpen: \(state)")
        return state
    }
}
