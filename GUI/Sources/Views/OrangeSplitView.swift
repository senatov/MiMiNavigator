    //
    //  OrangeSplitView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 30.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI

    // MARK: - SwiftUI wrapper around a customized NSSplitView
public struct OrangeSplitView<Left: View, Right: View>: NSViewRepresentable {
        // External state
    @Binding var leftWidth: CGFloat
    let totalWidth: CGFloat
    let left: Left
    let right: Right
    
        // Callbacks
    var onResize: ((CGFloat, CGFloat) -> Void)? = nil  // (left, total)
    var onDoubleClick: (() -> Void)? = nil
    
        // Appearance
    var normalThickness: CGFloat = 1.5
    var activeThickness: CGFloat = 3.0
    var normalColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.55)
    var activeColor: NSColor = .systemOrange
    var hitExpansion: CGFloat = 24
    
    public init(
        leftWidth: Binding<CGFloat>,
        totalWidth: CGFloat,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right,
        onResize: ((CGFloat, CGFloat) -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        normalThickness: CGFloat = 1.5,
        activeThickness: CGFloat = 3.0,
        normalColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.55),
        activeColor: NSColor = .systemOrange,
        hitExpansion: CGFloat = 24
    ) {
        self._leftWidth = leftWidth
        self.totalWidth = totalWidth
        self.left = left()
        self.right = right()
        self.onResize = onResize
        self.onDoubleClick = onDoubleClick
        self.normalThickness = normalThickness
        self.activeThickness = activeThickness
        self.normalColor = normalColor
        self.activeColor = activeColor
        self.hitExpansion = hitExpansion
    }
    
    public func makeNSView(context: Context) -> NSSplitView {
        let sv = CustomSplitView()
        sv.isVertical = true
        sv.dividerStyle = .thin
        sv.delegate = context.coordinator
        sv.translatesAutoresizingMaskIntoConstraints = false
        
            // Configure appearance
        sv.appearanceProxy.normalThickness = normalThickness
        sv.appearanceProxy.activeThickness = activeThickness
        sv.appearanceProxy.normalColor = normalColor
        sv.appearanceProxy.activeColor = activeColor
        sv.appearanceProxy.hitExpansion = hitExpansion
        
            // Host SwiftUI children
        let leftHost = NSHostingView(rootView: left)
        let rightHost = NSHostingView(rootView: right)
        leftHost.translatesAutoresizingMaskIntoConstraints = false
        rightHost.translatesAutoresizingMaskIntoConstraints = false
        
        sv.addArrangedSubview(leftHost)
        sv.addArrangedSubview(rightHost)
        
            // Initial divider position
        DispatchQueue.main.async {
            let total = max(self.totalWidth, 1)
            let clamped = min(max(self.leftWidth, 0), total)
            sv.setPosition(clamped, ofDividerAt: 0)
            sv.needsDisplay = true
        }
        
            // Double-click recognizer
        let dbl = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        dbl.numberOfClicksRequired = 2
        sv.addGestureRecognizer(dbl)
        
            // Pan to toggle active thickness
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sv.addGestureRecognizer(pan)
        
        context.coordinator.splitView = sv
        return sv
    }
        // MARK: -
    public func updateNSView(_ sv: NSSplitView, context: Context) {
        let total = max(totalWidth, 1)
        let desired = min(max(leftWidth, 0), total)
            // Keep in sync with binding if changed externally
        if abs(desired - (sv.subviews.first?.frame.width ?? 0)) >= 1.0 {
            sv.setPosition(desired, ofDividerAt: 0)
        }
        sv.needsDisplay = true
    }
    
        // MARK: -
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
        // MARK: - Coordinator + Delegate
    @MainActor
    public final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: OrangeSplitView
        weak var splitView: CustomSplitView?
        
        init(_ parent: OrangeSplitView) { self.parent = parent }
        
        public func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let sv = splitView ?? notification.object as? NSSplitView else { return }
            let left = sv.subviews.first?.frame.width ?? 0
            let total = sv.bounds.width
            
            if abs(parent.leftWidth - left) >= 1.0 {
                parent.leftWidth = left
                    // Log via SwiftyBeaver (global `log`)
                log.debug("Split resized → \(Int(left))/\(Int(total))")
                parent.onResize?(left, total)
            }
            sv.needsDisplay = true
        }
        
            // Clamp + optional snap points
        public func splitView(
            _ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let total = max(splitView.bounds.width, 1)
            let minW: CGFloat = 0
            let maxW: CGFloat = total
            let snaps: [CGFloat] = [0.33, 0.5, 0.66].map { $0 * total }
            let near = snaps.first { abs($0 - proposedPosition) <= 8 }
            let snapped = near ?? proposedPosition
            return min(max(snapped, minW), maxW)
        }
        
            // MARK: -
        public func splitView(
            _ splitView: NSSplitView,
            effectiveRect proposedEffectiveRect: NSRect,
            forDrawnRect drawnRect: NSRect,
            ofDividerAt dividerIndex: Int
        ) -> NSRect {
            if let sv = splitView as? CustomSplitView {
                return drawnRect.insetBy(dx: -sv.appearanceProxy.hitExpansion, dy: 0)
            }
            return drawnRect
        }
        
            // MARK: -
        @objc func handleDoubleClick(_ gr: NSClickGestureRecognizer) {
            guard let sv = splitView else { return }
                // Compute divider rect manually to avoid API ambiguities
            let leftFrame = sv.subviews.first?.frame ?? .zero
            let dividerRect = NSRect(x: leftFrame.maxX,
                                     y: 0,
                                     width: sv.dividerThickness,
                                     height: sv.bounds.height)
                .insetBy(dx: -sv.appearanceProxy.hitExpansion, dy: 0)
            let clickPoint = gr.location(in: sv)
            if dividerRect.contains(clickPoint) {
                let half = sv.bounds.width / 2
                sv.setPosition(half, ofDividerAt: 0)
                parent.onDoubleClick?()
                log.debug("Split double-click → 50/50")
                sv.needsDisplay = true
            }
        }
        
            // MARK: -
        @objc func handlePan(_ gr: NSPanGestureRecognizer) {
            guard let sv = splitView else { return }
            switch gr.state {
                case .began:
                    sv.appearanceProxy.isDragging = true
                    sv.invalidateDivider()
                case .ended, .cancelled:
                    sv.appearanceProxy.isDragging = false
                    sv.invalidateDivider()
                default: break
            }
        }
    }
}
