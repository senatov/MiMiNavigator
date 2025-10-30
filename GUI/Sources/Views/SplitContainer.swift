    //
    //  SplitContainer.swift
    //  MiMiNavigator
    //
    //  Reworked: binding-based width sync, verbose logging, glossy 6pt divider.
    //  Swift 6.2 / macOS 15.4+. Comments in English only.
    //

import AppKit
import SwiftUI

    // MARK: - Custom split view with glossy blue-gray divider
@MainActor final class GlassSplitView: NSSplitView {
    override var isOpaque: Bool { false }
    override var dividerThickness: CGFloat { 6 }
    
    override func drawDivider(in rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let r = rect.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(roundedRect: r, xRadius: 2.5, yRadius: 2.5)
        ctx.saveGState()
        path.addClip()
        let colors =
        [
            NSColor(calibratedRed: 0.82, green: 0.88, blue: 0.96, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.66, green: 0.74, blue: 0.88, alpha: 1).cgColor,
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [])
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.25, alpha: 0.18).cgColor)
        ctx.setLineWidth(0.5)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    override func mouseDown(with event: NSEvent) {
        log.debug("GlassSplitView.mouseDown – begin drag")
        super.mouseDown(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        log.debug("GlassSplitView.mouseUp – end drag; posting dividerDragEnded")
        NotificationCenter.default.post(name: .dividerDragEnded, object: nil)
    }
}

    // MARK: - NSViewRepresentable wrapper
@MainActor struct SplitContainer<Left: View, Right: View>: NSViewRepresentable {
    typealias NSViewType = NSSplitView
    
    @ViewBuilder var leftPanel: () -> Left
    @ViewBuilder var rightPanel: () -> Right
    
        // Bind width from SwiftUI. No AppStorage here to avoid feedback loops.
    @Binding var leftPanelWidth: CGFloat
    var minPanelWidth: CGFloat = 220
    
    func makeNSView(context: Context) -> NSSplitView {
        log.debug("SplitContainer.makeNSView – creating split view")
        let split = GlassSplitView()
        split.isVertical = true
        split.dividerStyle = .paneSplitter
        split.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")
        split.autosaveName = "MiMi.Split"
        split.translatesAutoresizingMaskIntoConstraints = false
        split.delegate = context.coordinator
        
        let leftHost = NSHostingView(rootView: leftPanel())
        let rightHost = NSHostingView(rootView: rightPanel())
        split.addArrangedSubview(leftHost)
        split.addArrangedSubview(rightHost)
        
            // Apply initial position on next runloop to ensure frames are valid
        DispatchQueue.main.async { [weak split] in
            guard let split else { return }
            let pos = self.leftPanelWidth.clamped(self.minPanelWidth, .greatestFiniteMagnitude)
            log.debug("SplitContainer.makeNSView – initial setPosition to left=\(Int(pos))")
            split.setPosition(pos, ofDividerAt: 0)
            split.layoutSubtreeIfNeeded()
        }
        return split
    }
    
    func updateNSView(_ splitView: NSSplitView, context: Context) {
            // Update hosted views (keeps SwiftUI content fresh)
        if let leftHost = splitView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = leftPanel()
        }
        if let rightHost = splitView.arrangedSubviews.last as? NSHostingView<Right> {
            rightHost.rootView = rightPanel()
        }
            // Sync divider position if external binding changed meaningfully
        let current = splitView.arrangedSubviews.first?.frame.width ?? leftPanelWidth
        if abs(current - leftPanelWidth) > 0.5 {
            let pos = leftPanelWidth.clamped(minPanelWidth, .greatestFiniteMagnitude)
            log.debug("SplitContainer.updateNSView – sync setPosition to left=\(Int(pos)) (current=\(Int(current)))")
            splitView.setPosition(pos, ofDividerAt: 0)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
        // MARK: - Coordinator
    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: SplitContainer
        private var lastSentLeftWidth: CGFloat = -1
        init(parent: SplitContainer) { self.parent = parent }
        
        func splitView(
            _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            parent.minPanelWidth
        }
        func splitView(
            _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let total = splitView.frame.width
            return max(parent.minPanelWidth, total - parent.minPanelWidth - splitView.dividerThickness)
        }
        func splitView(_ splitView: NSSplitView, didResizeSubviews notification: Notification) {
            let leftWidth = splitView.arrangedSubviews.first?.frame.width ?? 0
            let total = splitView.frame.width
                // Rate-limit updates to binding to avoid feedback cycles
            if abs(leftWidth - lastSentLeftWidth) > 0.5 {
                lastSentLeftWidth = leftWidth
                parent.leftPanelWidth = leftWidth
                log.debug(
                    "SplitContainer.didResize – left=\(Int(leftWidth)) / total=\(Int(total)) / divider=\(splitView.dividerThickness)")
                    // Tooltip update with pointer location (converted to splitView coords)
                let dividerX = leftWidth
                let pointer = currentPointer(in: splitView)
                log.debug(
                    "SplitContainer.didResize – posting dividerDragChanged (dividerX=\(Int(dividerX)), pointer=\(Int(pointer.x));\(Int(pointer.y)))"
                )
                NotificationCenter.default.post(
                    name: .dividerDragChanged, object: nil,
                    userInfo: [
                        "dividerX": dividerX,
                        "pointer": pointer,
                    ])
            }
        }
        private func currentPointer(in splitView: NSSplitView) -> CGPoint {
            guard let window = splitView.window else { return CGPoint(x: splitView.bounds.midX, y: splitView.bounds.midY) }
            let screenPt = NSEvent.mouseLocation
            let winPt = window.convertPoint(fromScreen: screenPt)
            return splitView.convert(winPt, from: nil)
        }
    }
}

@MainActor
extension CGFloat {
    fileprivate func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        return Swift.min(Swift.max(self, lo), hi)
    }
}
