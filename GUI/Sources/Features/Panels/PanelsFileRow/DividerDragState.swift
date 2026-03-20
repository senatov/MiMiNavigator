//
//  DividerDragState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Divider Drag State
struct DividerDragState {
    var isDragging: Bool = false
    var dragStartWidth: CGFloat = .nan
    var lastAppliedWidth: CGFloat = -1
    var dragGrabOffset: CGFloat = 0
    var dragPreviewLeft: CGFloat?
    var suppressDragUntilMouseUp: Bool = false
    // Tooltip
    var tooltipText: String = ""
    var tooltipPosition: CGPoint = .zero
    var isTooltipVisible: Bool = false
    var lastTooltipLeft: CGFloat = .nan
    // Throttling
    var lastLoggedWidth: CGFloat = -1
    var lastUILogTS: TimeInterval = 0
}
