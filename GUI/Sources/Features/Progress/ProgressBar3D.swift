// ProgressBar3D.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.07.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Glass progress bar using the standard macOS accent color.

import AppKit

// MARK: - Progress Bar 3D
@MainActor final class ProgressBar3D: NSView {
    private var fraction: Double?
    private var detailText = "Estimating progress…"
    private var animationPhase: CGFloat = 0
    private var animationTimer: Timer?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }

    // MARK: - Progress
    func setProgress(_ fraction: Double, detail: String) {
        stopAnimating()
        self.fraction = min(max(fraction, 0), 1)
        detailText = detail
        needsDisplay = true
    }

    // MARK: - Indeterminate
    func setIndeterminate(_ detail: String = "Estimating progress…") {
        fraction = nil
        detailText = detail
        startAnimating()
        needsDisplay = true
    }

    // MARK: - Start Animation
    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1 / 30,
            target: self,
            selector: #selector(animationTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func animationTick() {
        animationPhase = (animationPhase + 0.018).truncatingRemainder(dividingBy: 1)
        needsDisplay = true
    }

    // MARK: - Stop Animation
    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Draw
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let barRect = bounds.insetBy(dx: 1.5, dy: 2.5)
        drawTrack(in: barRect)
        drawFill(in: barRect)
        drawLabel(in: barRect)
    }

    // MARK: - Draw Track
    private func drawTrack(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.separatorColor.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }

    // MARK: - Draw Fill
    private func drawFill(in rect: NSRect) {
        let fillRect: NSRect
        if let fraction {
            fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height)
        } else {
            let segmentWidth = max(70, rect.width * 0.28)
            let travel = rect.width + segmentWidth
            fillRect = NSRect(x: rect.minX - segmentWidth + travel * animationPhase, y: rect.minY, width: segmentWidth, height: rect.height)
        }
        let clippedRect = fillRect.intersection(rect)
        guard clippedRect.width > 0 else { return }
        let radius = min(rect.height / 2, clippedRect.width / 2)
        let path = NSBezierPath(roundedRect: clippedRect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let accent = NSColor.controlAccentColor
        let gradient = NSGradient(colors: [
            accent.highlight(withLevel: 0.22) ?? accent,
            accent,
            accent.shadow(withLevel: 0.18) ?? accent
        ])
        gradient?.draw(in: clippedRect, angle: -90)
        let highlightRect = NSRect(x: clippedRect.minX, y: clippedRect.midY, width: clippedRect.width, height: clippedRect.height * 0.46)
        let highlight = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.68),
            NSColor.white.withAlphaComponent(0.04)
        ])
        highlight?.draw(in: highlightRect, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Draw Label
    private func drawLabel(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .shadow: labelShadow
        ]
        let size = detailText.size(withAttributes: attributes)
        let textRect = NSRect(x: rect.minX + 4, y: rect.midY - size.height / 2, width: rect.width - 8, height: size.height)
        detailText.draw(in: textRect, withAttributes: attributes)
    }

    private var labelShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
        shadow.shadowBlurRadius = 1.5
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        return shadow
    }
}
