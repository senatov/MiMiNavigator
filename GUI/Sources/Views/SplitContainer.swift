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
    
        // ViewBuilder closures for left and right panels
    @ViewBuilder var leftPanel: () -> Left
    @ViewBuilder var rightPanel: () -> Right
    
        // Appearance & layout tuning
    let minPanelWidth: CGFloat = 120
    
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
        splitView.autosaveName = NSSplitView.AutosaveName("MiMiSplit")
        splitView.delegate = context.coordinator
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")
        
            // Host SwiftUI children
        let leftHost = NSHostingView(rootView: leftPanel())
        let rightHost = NSHostingView(rootView: rightPanel())
        leftHost.translatesAutoresizingMaskIntoConstraints = false
        rightHost.translatesAutoresizingMaskIntoConstraints = false
        
        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)
        
            // Apply initial divider position on next runloop when bounds are valid
        DispatchQueue.main.async {
            let total = max(splitView.bounds.width, 1)
            let clamped = clampLeftWidth(self.leftPanelWidth, totalWidth: total, minPanelWidth: self.minPanelWidth, dividerThickness: splitView.dividerThickness)
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
        let desired = clampLeftWidth(leftPanelWidth, totalWidth: total, minPanelWidth: minPanelWidth, dividerThickness: splitView.dividerThickness)
        let current = splitView.arrangedSubviews.first?.frame.width ?? 0
        if abs(desired - current) >= 1.0 && abs(desired - (context.coordinator.lastSetPosition.isNaN ? -9999 : context.coordinator.lastSetPosition)) >= 1.0 {
            context.coordinator.isProgrammatic = true
            splitView.setPosition(desired, ofDividerAt: 0)
            context.coordinator.lastSetPosition = desired
            DispatchQueue.main.async { context.coordinator.isProgrammatic = false }
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
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
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
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            parent.minPanelWidth
        }
        
            // Max coordinate constraint
        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let total = splitView.frame.width
            return total - parent.minPanelWidth - splitView.dividerThickness
        }
        
        
            // Handle double-click on divider: reset to 50/50
        @objc func handleDoubleClick(_ gr: NSClickGestureRecognizer) {
            guard let sv = gr.view as? NSSplitView else { return }
            let half = sv.bounds.width / 2
            let clamped = (half * (NSScreen.main?.backingScaleFactor ?? 2.0)).rounded() / (NSScreen.main?.backingScaleFactor ?? 2.0)
            isProgrammatic = true
            sv.setPosition(clamped, ofDividerAt: 0)
            lastSetPosition = clamped
            parent.leftPanelWidth = clamped
            isProgrammatic = false
            log.debug("SplitContainer.doubleClick → 50/50 (\(Int(clamped)))")
        }
    }
}
