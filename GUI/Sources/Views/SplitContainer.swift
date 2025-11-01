    //
    //  SplitContainer.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 30.10.2025.
    //

import AppKit
import SwiftUI

    /// Native NSSplitView wrapper that manages left/right panels with min widths and persistent left width
struct SplitContainer<Left: View, Right: View>: NSViewRepresentable {
    typealias NSViewType = NSSplitView
    
        // Stored closures for left and right panels (no @ViewBuilder on storage)
    let leftPanel: () -> Left
    let rightPanel: () -> Right
    
    let minPanelWidth: CGFloat
    
    init(
        minPanelWidth: CGFloat = 120,
        @ViewBuilder leftPanel: @escaping () -> Left,
        @ViewBuilder rightPanel: @escaping () -> Right
    ) {
        self.minPanelWidth = minPanelWidth
        self.leftPanel = leftPanel
        self.rightPanel = rightPanel
    }
    
        // Persisted left panel width
    @AppStorage("leftPanelWidth") private var leftPanelWidthValue: Double = 400
    private var leftPanelWidth: CGFloat {
        get { CGFloat(leftPanelWidthValue) }
        set { leftPanelWidthValue = Double(newValue) }
    }
    
        // MARK: - NSViewRepresentable
    
    @MainActor
    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
            // Prefer keeping the left panel width stable; right side flexes first on window resize
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 1)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")
        
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
        
            // Double-click to reset to 50/50
        let dbl = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        dbl.numberOfClicksRequired = 2
        splitView.addGestureRecognizer(dbl)
        
        return splitView
    }
    
    @MainActor
    func updateNSView(_ splitView: NSSplitView, context: Context) {
            // Update hosted SwiftUI content
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
    
    @MainActor
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
        // MARK: - Helpers
    
        /// Clamp left width to respect min width on both sides
    private func clampLeftWidth(_ left: CGFloat, totalWidth: CGFloat, minPanelWidth: CGFloat, dividerThickness: CGFloat) -> CGFloat {
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
        
            // Min coordinate constraint
        func splitView(
            _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
                // Respect system proposal, but never allow the left panel to be smaller than our minimum
            return max(proposedMinimumPosition, parent.minPanelWidth)
        }
        
            // Max coordinate constraint
        func splitView(
            _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
                // Ensure the right panel also respects the minimum width when the divider moves right
            let total = splitView.bounds.width
            let maxAllowed = total - parent.minPanelWidth - splitView.dividerThickness
            return min(proposedMaximumPosition, maxAllowed)
        }
        
            // Persist user-driven divider drags
        func splitViewDidResizeSubviews(_ splitView: NSSplitView) {
                // Ignore programmatic changes to avoid feedback loops
            guard !isProgrammatic, let left = splitView.arrangedSubviews.first else { return }
            
            let total = max(splitView.bounds.width, 1)
            let scale = splitView.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
            
                // Snap the measured width to pixel grid
            let measured = left.frame.width
            let snapped = (measured * scale).rounded() / scale
            
                // Also respect min widths via the same clamp helper used elsewhere
            let clamped = parent.clampLeftWidth(snapped,
                                                totalWidth: total,
                                                minPanelWidth: parent.minPanelWidth,
                                                dividerThickness: splitView.dividerThickness)
            
                // Update lastSetPosition and persist if it actually changed
            lastSetPosition = clamped
            if abs(parent.leftPanelWidth - clamped) >= 0.5 {
                parent.leftPanelWidth = clamped
                log.debug("SplitContainer.drag → left=\(Int(clamped)) total=\(Int(total))")
            }
        }
        
            // Handle double-click on divider: reset to 50/50
        @objc func handleDoubleClick(_ gr: NSClickGestureRecognizer) {
            guard let sv = gr.view as? NSSplitView else { return }
            
                // Only trigger when the click lands on the divider (with a small tolerance)
                // Manually compute divider rect using first subview's maxX and dividerThickness
            let dividerX = (sv.arrangedSubviews.first?.frame.maxX ?? 0)
            let dividerRect = NSRect(x: dividerX, y: 0, width: sv.dividerThickness, height: sv.bounds.height)
            let hit = dividerRect.insetBy(dx: -3, dy: -6) // expand hitbox slightly
            let loc = gr.location(in: sv)
            guard hit.contains(loc) else { return }
            
                // Target is 50/50, but clamp to respect min widths and snap to pixel grid
            let total = max(sv.bounds.width, 1)
            let desired = parent.clampLeftWidth(total / 2,
                                                totalWidth: total,
                                                minPanelWidth: parent.minPanelWidth,
                                                dividerThickness: sv.dividerThickness)
            
            isProgrammatic = true
            sv.setPosition(desired, ofDividerAt: 0)
            lastSetPosition = desired
            parent.leftPanelWidth = desired
            DispatchQueue.main.async { [weak self] in self?.isProgrammatic = false }
            log.debug("SplitContainer.doubleClick → 50/50 (\(Int(desired)))")
        }
    }
}
