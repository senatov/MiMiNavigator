//
//  DragNSViewUI.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

struct DragNSViewUI {
    static let dragThreshold: CGFloat = 5.0
    static let dragStartTolerance: CGFloat = 10.0
    static let samePanelDropReturnTolerance: CGFloat = 28.0
    static let dropTargetProbeYOffset: CGFloat = 14.0
    static let dropPreviewSize = NSSize(width: 36, height: 36)
    static let dropPreviewFadeDuration: TimeInterval = 0.16
    static let dropPreviewEndScale: CGFloat = 0.92
}
