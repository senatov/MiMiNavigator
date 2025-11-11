//
//  SplitContainer.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//

import AppKit
import SwiftUI

// MARK: - Native NSSplitView wrapper that manages left/right panels with min widths and persistent left width
struct SplitContainer<Left: View, Right: View>: NSViewRepresentable {
    typealias NSViewType = NSSplitView

    // Stored closures for left and right panels (no @ViewBuilder on storage)
    let leftPanel: () -> Left
    let rightPanel: () -> Right
    let minPanelWidth: CGFloat

    // MARK: - Verbose logging toggle for interaction diagnostics (computed to avoid static stored property in generics)
    private static var verboseLogs: Bool { true }

    // MARK: -
    private func V(_ msg: @autoclosure () -> String) {
        if Self.verboseLogs { log.debug(msg()) }
    }

    // MARK: -Custom NSSplitView that intercepts double-clicks on the divider
    final class ResettableSplitView: NSSplitView {
        weak var coordinatorRef: Coordinator?

        // Responder overrides to allow keyboard/focus and modifier event handling
        override var acceptsFirstResponder: Bool { true }
        override func becomeFirstResponder() -> Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.window?.acceptsMouseMovedEvents = true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
            let dividerRect = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
            if dividerRect.contains(point) { return self }
            return super.hitTest(point)
        }

        // MARK: -
        override func mouseDown(with event: NSEvent) {
            // Make sure this view receives key and modifier updates
            self.window?.makeFirstResponder(self)
            let loc = convert(event.locationInWindow, from: nil)
            let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
            let hit = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
            // Debug print
            log.debug(
                "SV.mouseDown clickCount=\(event.clickCount) loc=\(NSStringFromPoint(loc)) hit=\(NSStringFromRect(hit)) flags=\(event.modifierFlags)"
            )
            // Option + single left click → reset split to 50/50
            if event.clickCount == 1,
                event.type == .leftMouseDown,
                event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
                hit.contains(loc)
            {
                log.debug("SV.option-left inside divider hitbox → reset to 50/50")
                if let coord = coordinatorRef {
                    DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
                }
                return
            }
            // Double click fallback
            if event.clickCount == 2, hit.contains(loc) {
                log.debug("SV.double-click divider → reset to 50/50")
                if let coord = coordinatorRef {
                    DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
                }
                return
            }
            super.mouseDown(with: event)
        }

        // MARK: -
        override func rightMouseDown(with event: NSEvent) {
            if SplitContainer.verboseLogs {
                let locWin = event.locationInWindow
                let locView = convert(locWin, from: nil)
                log.debug(
                    "SV.rightMouseDown count=\(event.clickCount) locWin=\(NSStringFromPoint(locWin)) locView=\(NSStringFromPoint(locView))"
                )
            }
            let loc = convert(event.locationInWindow, from: nil)
            let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
            let hit = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
            if SplitContainer.verboseLogs {
                log.debug("SV.right? loc=\(NSStringFromPoint(loc)) hit=\(NSStringFromRect(hit))")
            }
            if hit.contains(loc) {
                if SplitContainer.verboseLogs {
                    log.debug("SV.right → inside divider hitbox, forwarding to coordinator")
                }
                if let coord = coordinatorRef {
                    DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
                }
                return
            }
            super.rightMouseDown(with: event)
        }
    }

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

    // MARK: - Persisted left panel width
    @AppStorage("leftPanelWidth") private var leftPanelWidthValue: Double = 400
    private var leftPanelWidth: CGFloat {
        get { CGFloat(leftPanelWidthValue) }
        set { leftPanelWidthValue = Double(newValue) }
    }

    // MARK: - NSViewRepresentable
    @MainActor
    func makeNSView(context: Context) -> NSSplitView {
        log.debug(#function)
        let splitView = ResettableSplitView()
        splitView.coordinatorRef = context.coordinator
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        // Prefer keeping the left panel width stable; right side flexes first on window resize
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 1)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")
        V("SV.init isVertical=\(splitView.isVertical) dividerStyle=\(splitView.dividerStyle.rawValue) minWidth=\(minPanelWidth)")
        // Host SwiftUI children
        let leftHost = NSHostingView(rootView: leftPanel())
        let rightHost = NSHostingView(rootView: rightPanel())
        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)
        // Apply initial divider position on next runloop when bounds are valid
        DispatchQueue.main.async {
            let total = max(splitView.bounds.width, 1)
            let clamped = clampLeftWidth(
                self.leftPanelWidth, totalWidth: total, minPanelWidth: self.minPanelWidth, dividerThickness: splitView.dividerThickness
            )
            context.coordinator.isProgrammatic = true
            splitView.setPosition(clamped, ofDividerAt: 0)
            context.coordinator.lastSetPosition = clamped
            context.coordinator.isProgrammatic = false
            log.debug("SplitContainer.makeNSView → initial left=\(Int(clamped)) total=\(Int(total))")
        }
        // Gesture recognizer not needed: Option+Left click is handled in ResettableSplitView.mouseDown(_:).
        return splitView
    }

    // MARK: - Update hosted SwiftUI content
    @MainActor
    func updateNSView(_ splitView: NSSplitView, context: Context) {
        log.debug(#function)
        if let leftHost = splitView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = leftPanel()
        }
        if let rightHost = splitView.arrangedSubviews.last as? NSHostingView<Right> {
            rightHost.rootView = rightPanel()
        }
        // Sync divider position with persisted width without causing feedback loops
        let total = max(splitView.bounds.width, 1)
        let desired = clampLeftWidth(
            leftPanelWidth,
            totalWidth: total,
            minPanelWidth: minPanelWidth,
            dividerThickness: splitView.dividerThickness
        )
        let current = splitView.arrangedSubviews.first?.frame.width ?? 0
        if !context.coordinator.isProgrammatic {
            let delta = abs(desired - current)
            if delta >= 0.5 {
                context.coordinator.isProgrammatic = true
                splitView.setPosition(desired, ofDividerAt: 0)
                context.coordinator.lastSetPosition = desired
                context.coordinator.isProgrammatic = false
            }
        }
    }

    // MARK: -
    @MainActor
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Clamp left width to respect min width on both sides
    private func clampLeftWidth(_ left: CGFloat, totalWidth: CGFloat, minPanelWidth: CGFloat, dividerThickness: CGFloat) -> CGFloat {
        log.debug(#function)
        let minLeft = minPanelWidth
        let maxLeft = max(minPanelWidth, totalWidth - minPanelWidth - dividerThickness)
        // Snap to pixel grid to avoid half-pixel jitter
        let scale = NSApp.mainWindow?.backingScaleFactor ?? 2.0
        let clamped = max(minLeft, min(left, maxLeft))
        return (clamped * scale).rounded() / scale
    }

    // MARK: - Coordinator
    @MainActor
    class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: SplitContainer
        // Re-entrancy guards to prevent feedback loops
        var isProgrammatic: Bool = false
        var lastSetPosition: CGFloat = .nan
        init(_ parent: SplitContainer) {
            self.parent = parent
        }

        // MARK: - Min coordinate constraint
        func splitView(
            _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            log.debug(#function)
            // Respect system proposal, but never allow the left panel to be smaller than our minimum
            return max(proposedMinimumPosition, parent.minPanelWidth)
        }

        // MARK: - MARK: - Max coordinate constraint
        func splitView(
            _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            // Ensure the right panel also respects the minimum width when the divider moves right
            let total = splitView.bounds.width
            let maxAllowed = total - parent.minPanelWidth - splitView.dividerThickness
            return min(proposedMaximumPosition, maxAllowed)
        }

        // MARK: -Enlarge effective divider rect to make double-click detection less finicky
        func splitView(
            _ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect,
            ofDividerAt dividerIndex: Int
        ) -> NSRect {
            log.debug(#function)
            return drawnRect.insetBy(dx: -3, dy: -6)
        }

        // MARK: - Allow our recognizer to work alongside SplitView's internal tracking

        // MARK: - Persist user-driven divider drags (correct NSSplitViewDelegate signature)
        func splitViewDidResizeSubviews(_ notification: Notification) {
            log.debug(#function)
            guard
                let splitView = notification.object as? NSSplitView,
                !isProgrammatic,
                let left = splitView.arrangedSubviews.first
            else { return }
            let total = max(splitView.bounds.width, 1)
            let scale =
                splitView.window?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 2.0
            // Snap the measured width to pixel grid
            let measured = left.frame.width
            let snapped = (measured * scale).rounded() / scale
            // Respect min widths via the same clamp helper used elsewhere
            let clamped = parent.clampLeftWidth(
                snapped,
                totalWidth: total,
                minPanelWidth: parent.minPanelWidth,
                dividerThickness: splitView.dividerThickness
            )
            // Update lastSetPosition and persist if it actually changed
            lastSetPosition = clamped
            if abs(parent.leftPanelWidth - clamped) >= 0.5 {
                parent.leftPanelWidth = clamped
                log.debug(
                    "SplitContainer.drag measured=\(Int(measured)) snapped=\(Int(snapped)) clamped=\(Int(clamped)) total=\(Int(total))"
                )
            }
        }

        // MARK: - Handle double-click coming directly from SplitView subclass
        @objc func handleDoubleClickFromSplitView(_ sv: NSSplitView) {
            if SplitContainer.verboseLogs {
                let leftMaxX = sv.arrangedSubviews.first?.frame.maxX ?? 0
                let drawn = NSRect(x: leftMaxX, y: 0, width: sv.dividerThickness, height: sv.bounds.height)
                let hit = drawn.insetBy(dx: -3, dy: -6)
                log.debug(
                    "DC.fromSV start total=\(Int(sv.bounds.width)) drawn=\(NSStringFromRect(drawn)) hit=\(NSStringFromRect(hit))")
            }
            let total = max(sv.bounds.width, 1)
            let desired = parent.clampLeftWidth(
                total / 2,
                totalWidth: total,
                minPanelWidth: parent.minPanelWidth,
                dividerThickness: sv.dividerThickness
            )
            isProgrammatic = true
            sv.setPosition(desired, ofDividerAt: 0)
            lastSetPosition = desired
            parent.leftPanelWidth = desired
            DispatchQueue.main.async { [weak self] in self?.isProgrammatic = false }
            log.debug("SplitContainer.doubleClick → 50/50 setPosition=\(Int(desired)) total=\(Int(total))")
        }
    }
}
