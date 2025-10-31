    //
    //  CustomSplitView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 30.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI

    // MARK: - Custom NSSplitView drawing a colored divider
public final class CustomSplitView: NSSplitView {
    let appearanceProxy = DividerAppearance()
    
        // MARK: -
    public override var dividerThickness: CGFloat {
        appearanceProxy.isDragging ? appearanceProxy.activeThickness : appearanceProxy.normalThickness
    }
    
        // MARK: -
    public override func drawDivider(in rect: NSRect) {
        log.debug(#function)
        let color = appearanceProxy.isDragging ? appearanceProxy.activeColor : appearanceProxy.normalColor
        color.setFill()
        rect.fill()
    }
    
        // MARK: -
    public func invalidateDivider() {
        setNeedsDisplay(bounds)
    }
}
