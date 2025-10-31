//
//  SplitContainer.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//

import AppKit
import SwiftUI

/// Native NSSplitView wrapper that manages left/right panels with a 6pt divider
struct SplitContainer<Left: View, Right: View>: NSViewRepresentable {
    typealias NSViewType = NSSplitView

    // ✅ ViewBuilder closures for left and right panels
    @ViewBuilder var leftPanel: () -> Left
    @ViewBuilder var rightPanel: () -> Right

    let dividerThickness: CGFloat = 6
    let minPanelWidth: CGFloat = 120

    @AppStorage("leftPanelWidth") private var leftPanelWidthValue: Double = 400
    private var leftPanelWidth: CGFloat {
        get { CGFloat(leftPanelWidthValue) }
        set { leftPanelWidthValue = Double(newValue) }
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = NSSplitView.AutosaveName("MiMiSplit")
        splitView.delegate = context.coordinator
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.identifier = NSUserInterfaceItemIdentifier("MiMiSplitView")

        // ✅ вызываем замыкания, чтобы получить реальные SwiftUI вью
        let leftHost = NSHostingView(rootView: leftPanel())
        let rightHost = NSHostingView(rootView: rightPanel())

        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)

        DispatchQueue.main.async {
            if leftPanelWidth > 0 {
                leftHost.setFrameSize(NSSize(width: leftPanelWidth, height: leftHost.frame.height))
            }
        }

        log.debug("SplitContainer.makeNSView → dividerThickness=\(dividerThickness)")
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        // ✅ обновляем хосты при изменениях
        if let leftHost = splitView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = leftPanel()
        }
        if let rightHost = splitView.arrangedSubviews.last as? NSHostingView<Right> {
            rightHost.rootView = rightPanel()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: SplitContainer
        init(_ parent: SplitContainer) {
            self.parent = parent
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            parent.minPanelWidth
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let totalWidth = splitView.frame.width
            return totalWidth - parent.minPanelWidth - splitView.dividerThickness
        }

        func splitView(_ splitView: NSSplitView, didResizeSubviews notification: Notification) {
            let leftWidth = splitView.arrangedSubviews.first?.frame.width ?? 0
            parent.leftPanelWidth = leftWidth
            log.debug("SplitContainer.resize → leftPanelWidth=\(Int(leftWidth))")
        }
    }
}
