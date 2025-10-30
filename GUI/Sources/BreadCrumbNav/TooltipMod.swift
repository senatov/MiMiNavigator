//
//  ToolTipMod.swift
//  MiMiNavigator
//
//  Updated: Tooltip utilities and view for divider drag percentage hint.
//  Swift 6.2, macOS 15.4+. Comments in English only.
//

import SwiftUI

/// Utility responsible for building the tooltip text and a sane position near the divider.
struct ToolTipMod {
    /// Builds human‑readable text like "Left: 42% | Right: 58%".
    /// - Parameters:
    ///   - dividerX: Current divider x in the parent coordinate space.
    ///   - totalWidth: Total width of the two‑panel container.
    /// - Returns: Tooltip string.
    static func buildText(dividerX: CGFloat, totalWidth: CGFloat) -> String {
        log.debug("\(#function) dividerX=\(dividerX), totalWidth=\(totalWidth)")
        guard totalWidth > 0 else { return "Left: 0% | Right: 0%" }
        let leftP = Int(max(0, min(100, (dividerX / totalWidth * 100).rounded())))
        let rightP = max(0, 100 - leftP)
        let text = "Left: \(leftP)% | Right: \(rightP)%"
        log.debug(text)
        return text
    }

    /// Alternative when you already know left fraction (0…1).
    static func buildText(leftFraction: CGFloat) -> String {
        let lf = max(0, min(1, leftFraction))
        let leftP = Int((lf * 100).rounded())
        let rightP = max(0, 100 - leftP)
        let text = "Left: \(leftP)% | Right: \(rightP)%"
        log.debug(text)
        return text
    }

    /// Calculates a visually pleasant tooltip position relative to a pointer or divider.
    /// Keeps it within the container bounds and auto-flips near edges.
    /// - Parameters:
    ///   - reference: Usually the current mouse location in the same coord space.
    ///   - dividerX: Divider x used as an anchor to avoid jumping.
    ///   - containerSize: Size of the container where the tooltip will be overlayed.
    /// - Returns: CGPoint for `.position(...)` in the overlay space (top‑leading origin).
    static func place(reference: CGPoint, dividerX: CGFloat, containerSize: CGSize) -> CGPoint {
        let margin: CGFloat = 12
        let aboveOffsetY: CGFloat = 18
        let sideOffsetX: CGFloat = 12

        // Prefer placing to the right of divider; flip to the left if too close to the right edge.
        var x = dividerX + sideOffsetX
        if dividerX > containerSize.width - 140 {  // close to right edge → place to the left
            x = dividerX - sideOffsetX
        }

        // Slightly above current pointer; clamp to safe area.
        var y = max(margin, reference.y - aboveOffsetY)

        // Clamp to container bounds with small margins
        x = min(max(margin, x), containerSize.width - margin)
        y = min(max(margin, y), containerSize.height - margin)

        // Snap to half‑pixel for crisper text on Retina
        x = snapToHalfPixel(x)
        y = snapToHalfPixel(y)

        let p = CGPoint(x: x, y: y)
        log.debug("place -> \(p)")
        return p
    }

    /// Snap coordinate to 0.5 pixel grid for sharper rendering on 2x scale.
    private static func snapToHalfPixel(_ v: CGFloat) -> CGFloat {
        (round(v * 2) / 2)
    }
}

/// A lightweight tooltip bubble that follows macOS "liquid glass" look.
struct DividerTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .allowsTightening(true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(radius: 8, x: 0, y: 2)
            .accessibilityLabel("Panel width tooltip")
            .accessibilityValue(Text(text))
    }
}

#if DEBUG
    struct DividerTooltip_Previews: PreviewProvider {
        static var previews: some View {
            ZStack(alignment: .topLeading) {
                Color.clear
                DividerTooltip(text: "Left: 40% | Right: 60%")
                    .position(x: 120, y: 60)
            }
            .frame(width: 300, height: 120)
            .previewLayout(.sizeThatFits)
        }
    }
#endif
