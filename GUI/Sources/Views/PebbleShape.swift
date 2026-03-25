//
//  PebbleShape.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: smooth pebble — rounded left, flatter top, rounder bottom, blunt right

import SwiftUI

// MARK: - PebbleShape
struct PebbleShape: Shape {

    // MARK: - path
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // start top-center of left round
        p.move(to: CGPoint(x: 0, y: h * 0.28))

        // top-left corner — rounded
        p.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.05),
            control: CGPoint(x: 0, y: 0)
        )
        // top edge — flatter curve toward right
        p.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.12),
            control: CGPoint(x: w * 0.50, y: -h * 0.02)
        )
        // right tip — blunt rounded
        p.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.88),
            control: CGPoint(x: w + w * 0.06, y: h * 0.50)
        )
        // bottom edge — rounder curve back left
        p.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.95),
            control: CGPoint(x: w * 0.50, y: h + h * 0.08)
        )
        // bottom-left corner — rounded
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.72),
            control: CGPoint(x: 0, y: h)
        )
        p.closeSubpath()
        return p
    }
}
