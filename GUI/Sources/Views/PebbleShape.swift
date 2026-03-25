// PebbleShape.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 25.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Descr: corner-triangle pebble — straight top + left edges (flush with panel corner),
//        convex curved hypotenuse, plus a mirrored curve on the bottom

import SwiftUI


// MARK: - PebbleShape
struct PebbleShape: Shape {


    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        // top-left corner — sharp right angle (flush with panel borders)
        p.move(to: CGPoint(x: 0, y: 0))
        // straight top edge → right
        p.addLine(to: CGPoint(x: w, y: 0))
        // curved hypotenuse — convex bulge outward from top-right to bottom-left
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h),
            control: CGPoint(x: w * 0.72, y: h * 0.72)
        )
        // straight left edge ↑ back to start
        p.closeSubpath()
        return p
    }
}
