// ProgressActionButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Custom action button used by ProgressPanel.

import AppKit

// MARK: - ProgressActionButton

final class ProgressActionButton: NSButton {
    // MARK: - Semantic
    enum Semantic {
        case cancel
        case confirm

        var borderColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.withAlphaComponent(0.9)
            case .confirm: return NSColor.systemGreen.withAlphaComponent(0.9)
            }
        }

        var titleColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.blended(withFraction: 0.35, of: .labelColor) ?? .labelColor
            case .confirm: return NSColor.systemGreen.blended(withFraction: 0.35, of: .labelColor) ?? .labelColor
            }
        }

        var glowColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.withAlphaComponent(0.25)
            case .confirm: return NSColor.systemGreen.withAlphaComponent(0.25)
            }
        }
    }

    var semantic: Semantic = .cancel {
        didSet {
            needsLayout = true
            updateAppearance()
        }
    }
    var onPress: (() -> Void)?

    private let baseGradient = CAGradientLayer()
    private let glossGradient = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let innerShadowLayer = CAShapeLayer()

    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Layout
    override func layout() {
        super.layout()
        guard let layer else { return }
        let buttonBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shapePath = CGPath(roundedRect: buttonBounds, cornerWidth: 9, cornerHeight: 9, transform: nil)
        baseGradient.frame = bounds
        glossGradient.frame = bounds
        borderLayer.frame = bounds
        borderLayer.path = shapePath
        innerShadowLayer.frame = bounds
        innerShadowLayer.path = shapePath
        layer.shadowPath = shapePath
        updateAppearance()
    }

    override func setButtonType(_ buttonType: NSButton.ButtonType) {
        super.setButtonType(buttonType)
        updateAppearance()
    }

    override func updateLayer() {
        super.updateLayer()
        updateAppearance()
    }

    // MARK: - First Mouse
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Mouse Down
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else {
            super.mouseDown(with: event)
            return
        }
        log.debug("[ProgressPanel] action button mouse down")
        onPress?()
    }

    // MARK: - Configure
    private func configure() {
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryPushIn)
        focusRingType = .none
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        imagePosition = .noImage
        font = .systemFont(ofSize: 12.5, weight: .semibold)
        contentTintColor = semantic.titleColor
        guard let layer else { return }
        layer.cornerRadius = 9
        layer.masksToBounds = false
        layer.backgroundColor = NSColor.clear.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: -2)
        configureLayers()
        updateAppearance()
    }

    // MARK: - Configure Layers
    private func configureLayers() {
        baseGradient.colors = [
            NSColor.white.withAlphaComponent(0.62).cgColor,
            #colorLiteral(red: 0.92, green: 0.92, blue: 0.92, alpha: 0.76).cgColor,
            #colorLiteral(red: 0.82, green: 0.82, blue: 0.82, alpha: 0.92).cgColor
        ]
        baseGradient.locations = [0, 0.42, 1]
        baseGradient.startPoint = CGPoint(x: 0.5, y: 1)
        baseGradient.endPoint = CGPoint(x: 0.5, y: 0)
        baseGradient.cornerRadius = 9
        glossGradient.colors = [
            NSColor.white.withAlphaComponent(0.52).cgColor,
            NSColor.white.withAlphaComponent(0.12).cgColor,
            NSColor.clear.cgColor
        ]
        glossGradient.locations = [0, 0.22, 0.8]
        glossGradient.startPoint = CGPoint(x: 0.5, y: 1)
        glossGradient.endPoint = CGPoint(x: 0.5, y: 0)
        glossGradient.cornerRadius = 9
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 1
        innerShadowLayer.fillColor = NSColor.clear.cgColor
        innerShadowLayer.strokeColor = NSColor.white.withAlphaComponent(0.35).cgColor
        innerShadowLayer.lineWidth = 1
        innerShadowLayer.opacity = 0.95
        layer?.addSublayer(baseGradient)
        layer?.addSublayer(glossGradient)
        layer?.addSublayer(innerShadowLayer)
        layer?.addSublayer(borderLayer)
    }

    // MARK: - Update Appearance
    private func updateAppearance() {
        let isPressed = cell?.isHighlighted ?? false
        let scale: CGFloat = isPressed ? 0.965 : 1
        layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        layer?.shadowColor = semantic.glowColor.cgColor
        layer?.shadowOpacity = isPressed ? 0.18 : 0.34
        layer?.shadowRadius = isPressed ? 2 : 4
        layer?.shadowOffset = CGSize(width: 0, height: isPressed ? -1 : -2)
        borderLayer.strokeColor = semantic.borderColor.cgColor
        innerShadowLayer.opacity = isEnabled ? 0.95 : 0.45
        updateGradient(isPressed: isPressed)
        updateTitle()
    }

    // MARK: - Update Gradient
    private func updateGradient(isPressed: Bool) {
        let topAlpha: CGFloat = isEnabled ? (isPressed ? 0.48 : 0.62) : 0.28
        let midAlpha: CGFloat = isEnabled ? (isPressed ? 0.62 : 0.76) : 0.36
        let bottomAlpha: CGFloat = isEnabled ? (isPressed ? 0.78 : 0.92) : 0.48
        baseGradient.colors = [
            NSColor.white.withAlphaComponent(topAlpha).cgColor,
            #colorLiteral(red: 0.92, green: 0.92, blue: 0.92, alpha: 1).withAlphaComponent(midAlpha).cgColor,
            #colorLiteral(red: 0.82, green: 0.82, blue: 0.82, alpha: 1).withAlphaComponent(bottomAlpha).cgColor
        ]
        glossGradient.opacity = isPressed ? 0.55 : 1
    }

    // MARK: - Update Title
    private func updateTitle() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font ?? NSFont.systemFont(ofSize: 12.5, weight: .semibold),
                .foregroundColor: isEnabled ? semantic.titleColor : NSColor.disabledControlTextColor,
                .paragraphStyle: paragraph,
                .kern: 0.15
            ]
        )
    }
}
