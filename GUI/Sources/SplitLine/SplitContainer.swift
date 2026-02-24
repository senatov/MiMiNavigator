//
// SplitContainer.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//

import AppKit
import SwiftUI

// MARK: - Native NSSplitView wrapper that manages left/right panels with min widths and persistent left width
struct SplitContainer<Left: View, Right: View>: NSViewRepresentable {
    typealias NSViewType = NSSplitView
    let leftPanel: () -> Left
    let rightPanel: () -> Right
    let minPanelWidth: CGFloat

    // MARK: - Coordinator
    typealias Coordinator = SplitContainerCoordinator<Left, Right>

    // MARK: - Verbose logging toggle for interaction diagnostics (computed to avoid static stored property in generics)
    static var verboseLogs: Bool { true }

    // MARK: -
    init(
        minPanelWidth: CGFloat = 120,
        @ViewBuilder leftPanel: @escaping () -> Left,
        @ViewBuilder rightPanel: @escaping () -> Right
    ) {
        log.debug(#function)
        self.minPanelWidth = minPanelWidth
        self.leftPanel = leftPanel
        self.rightPanel = rightPanel
    }

    // MARK: -
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: -
    private func vu(_ msg: @autoclosure () -> String) {
        if Self.verboseLogs { log.debug(msg()) }
    }

    // MARK: - Persisted left panel width (sentinel -1 = "not yet configured → use 50/50")
    @AppStorage("leftPanelWidth") fileprivate var leftPanelWidthValue: Double = -1

    var leftPanelWidth: CGFloat {
        get { CGFloat(leftPanelWidthValue) }
        set { leftPanelWidthValue = Double(newValue) }
    }

    /// True when no persisted width exists yet (fresh install / config reset)
    var needsInitialLayout: Bool { leftPanelWidthValue < 0 }

    // MARK: - NSViewRepresentable
    func makeNSView(context: Context) -> NSSplitView {
        log.debug(#function)
        let splitView = ResettableSplitView()
        splitView.coordinatorRef = context.coordinator as? SplitViewDoubleClickHandler
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        // Prefer keeping left panel width stable; right side flexes first on window resize
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 1)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")
        vu("SV.init isVertical=\(splitView.isVertical) dividerStyle=\(splitView.dividerStyle.rawValue) minWidth=\(minPanelWidth)")
        // Host SwiftUI children
        let leftHost = NSHostingView(rootView: leftPanel())
        let rightHost = NSHostingView(rootView: rightPanel())
        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)
        // Apply initial divider position on next runloop when bounds are valid
        DispatchQueue.main.async {
            let total = max(splitView.bounds.width, 1)
            // When config is missing/reset, default to 50/50 instead of a hardcoded value
            let desiredLeft = self.needsInitialLayout ? (total / 2.0) : self.leftPanelWidth
            let clamped = self.clampLeftWidth(
                desiredLeft, totalWidth: total, minPanelWidth: self.minPanelWidth, dividerThickness: splitView.dividerThickness
            )
            context.coordinator.isProgrammatic = true
            splitView.setPosition(clamped, ofDividerAt: 0)
            context.coordinator.lastSetPosition = clamped
            // Persist the computed 50/50 so subsequent updateNSView calls don't fight it
            if self.needsInitialLayout {
                var mutableSelf = self
                mutableSelf.leftPanelWidth = clamped
            }
            context.coordinator.isProgrammatic = false
            log.debug("SplitContainer.makeNSView → initial left=\(Int(clamped)) total=\(Int(total)) wasDefault=\(self.needsInitialLayout)")
        }
        // Gesture recognizer not needed: Option+Left click is handled in ResettableSplitView.mouseDown(_:).
        return splitView
    }

    // MARK: - Update hosted SwiftUI content
    func updateNSView(_ splitView: NSSplitView, context: Context) {
        log.debug(#function)
        if let leftHost = splitView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = leftPanel()
        }
        if let rightHost = splitView.arrangedSubviews.last as? NSHostingView<Right> {
            rightHost.rootView = rightPanel()
        }
        // Sync divider position w/ persisted width without causing feedback loops
        // Skip if not yet configured (sentinel -1) — makeNSView handles initial layout
        guard !needsInitialLayout, !context.coordinator.isProgrammatic else { return }
        let total = max(splitView.bounds.width, 1)
        let desired = clampLeftWidth(
            leftPanelWidth,
            totalWidth: total,
            minPanelWidth: minPanelWidth,
            dividerThickness: splitView.dividerThickness
        )
        let current = splitView.arrangedSubviews.first?.frame.width ?? 0
        let delta = abs(desired - current)
        if delta >= 0.5 {
            context.coordinator.isProgrammatic = true
            splitView.setPosition(desired, ofDividerAt: 0)
            context.coordinator.lastSetPosition = desired
            context.coordinator.isProgrammatic = false
        }
    }

    // MARK: - Clamp left width to respect min width on both sides
    func clampLeftWidth(_ left: CGFloat, totalWidth: CGFloat, minPanelWidth: CGFloat, dividerThickness: CGFloat) -> CGFloat {
        log.debug(#function)
        let minLeft = minPanelWidth
        let maxLeft = max(minPanelWidth, totalWidth - minPanelWidth - dividerThickness)
        // Snap to pixel grid to avoid half-pixel jitter
        let scale = NSApp.mainWindow?.backingScaleFactor ?? 2.0
        let clamped = max(minLeft, min(left, maxLeft))
        return (clamped * scale).rounded() / scale
    }
}
