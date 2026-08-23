// PathAutoCompletePopupController.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import Observation
import SwiftUI

// MARK: - Auto Complete Item
struct AutoCompleteItem: Identifiable, Equatable {
    let file: CustomFile
    let isRecent: Bool
    let matchPrefix: String

    var id: String { file.id }
    var name: String { file.nameStr }
    var isDirectory: Bool { file.isDirectory }
}

// MARK: - Auto Complete Popup Model
@MainActor
@Observable
final class AutoCompletePopupModel {
    var items: [AutoCompleteItem] = []
    var selectedIndex = 0
    var onHighlight: ((Int) -> Void)?
    var onSelect: ((AutoCompleteItem) -> Void)?

    // MARK: - Select Row
    func selectRow(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        onHighlight?(index)
    }

    // MARK: - Accept Item
    func acceptItem(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            log.debug("[PathAutoComplete] ignored stale click id='\(id)'")
            return
        }
        let item = items[index]
        selectedIndex = index
        onHighlight?(index)
        log.debug("[PathAutoComplete] accepted id='\(item.id)' index=\(index)")
        onSelect?(item)
    }

    // MARK: - Accept Selected Item
    func acceptSelectedItem() {
        guard items.indices.contains(selectedIndex) else { return }
        acceptItem(id: items[selectedIndex].id)
    }

}

// MARK: - Auto Complete Popup Controller
@MainActor
final class AutoCompletePopupController {
    private var panel: NSPanel?
    private let model = AutoCompletePopupModel()
    private var monitors = PopupEventMonitors()
    var anchorFrame: CGRect = .zero
    var onDismissedByClickOutside: (() -> Void)?

    private let rowHeight: CGFloat = 34
    private let maxVisibleRows = 8
    private let popupChromeHeight: CGFloat = 76
    private let recentSeparatorHeight: CGFloat = 7

    // MARK: - Show
    func show(
        items: [AutoCompleteItem],
        selectedIndex: Int,
        onHighlight: @escaping (Int) -> Void,
        onSelect: @escaping (AutoCompleteItem) -> Void
    ) {
        guard !items.isEmpty else {
            hide()
            return
        }
        model.items = items
        model.selectedIndex = selectedIndex
        model.onHighlight = onHighlight
        model.onSelect = onSelect
        let visibleRows = min(items.count, maxVisibleRows)
        let hasRecentSeparator = items.contains(where: \.isRecent) && items.contains { !$0.isRecent }
        let separatorHeight = hasRecentSeparator ? recentSeparatorHeight : 0
        let panelHeight = CGFloat(visibleRows) * rowHeight + popupChromeHeight + separatorHeight
        let panelWidth = max(anchorFrame.width, 420)
        if panel == nil {
            createPanel()
        }
        guard let panel, let window = NSApp.keyWindow else { return }
        let targetFrame = targetFrame(
            panelSize: NSSize(width: panelWidth, height: panelHeight),
            window: window
        )
        if panel.isVisible {
            updateVisiblePanel(panel, frame: targetFrame)
        } else {
            presentPanel(panel, from: window, frame: targetFrame)
        }
    }

    // MARK: - Hide
    func hide() {
        monitors.remove()
        guard let panel, panel.isVisible else {
            model.items = []
            return
        }
        let parentWindow = panel.parent
        let targetFrame = panel.frame.offsetBy(dx: 0, dy: 4)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = reduceMotion ? 0.08 : 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
                if !reduceMotion {
                    panel.animator().setFrame(targetFrame, display: true)
                }
            },
            completionHandler: {
                Task { @MainActor in
                    parentWindow?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            }
        )
        model.items = []
    }

    // MARK: - Select Row
    func selectRow(_ index: Int) {
        model.selectRow(index)
    }

    // MARK: - Accept Selected Row
    func acceptSelectedRow() {
        model.acceptSelectedItem()
    }


    // MARK: - Target Frame
    private func targetFrame(panelSize: NSSize, window: NSWindow) -> NSRect {
        let windowHeight = window.frame.height
        let anchorOrigin = window.convertPoint(
            toScreen: NSPoint(x: anchorFrame.minX, y: windowHeight - anchorFrame.maxY)
        )
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let gap: CGFloat = 6
        let belowY = anchorOrigin.y - panelSize.height - gap
        let aboveY = anchorOrigin.y + anchorFrame.height + gap
        let y = belowY >= screenFrame.minY ? belowY : min(aboveY, screenFrame.maxY - panelSize.height)
        let x = min(max(anchorOrigin.x, screenFrame.minX), screenFrame.maxX - panelSize.width)
        return NSRect(origin: NSPoint(x: x, y: y), size: panelSize)
    }

    // MARK: - Present Panel
    private func presentPanel(_ panel: NSPanel, from window: NSWindow, frame: NSRect) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let startFrame = reduceMotion ? frame : frame.offsetBy(dx: 0, dy: 4)
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.10 : 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
        installMonitors(for: panel)
    }

    // MARK: - Update Visible Panel
    private func updateVisiblePanel(_ panel: NSPanel, frame: NSRect) {
        panel.setFrame(frame, display: true)
    }

    // MARK: - Install Monitors
    private func installMonitors(for panel: NSPanel) {
        monitors.install(
            panel: panel,
            onHide: { [weak self] in self?.hide() },
            onClickOutside: { [weak self] in self?.onDismissedByClickOutside?() },
            shouldDismissOnClick: { [weak self] _ in
                guard let self else { return true }
                return !(self.anchorScreenRect()?.contains(NSEvent.mouseLocation) ?? false)
            },
            installResignObserver: true
        )
    }

    // MARK: - Anchor Screen Rect
    private func anchorScreenRect() -> NSRect? {
        guard let window = NSApp.keyWindow else { return nil }
        let windowHeight = window.frame.height
        let origin = window.convertPoint(
            toScreen: NSPoint(x: anchorFrame.minX, y: windowHeight - anchorFrame.maxY)
        )
        return NSRect(origin: origin, size: anchorFrame.size)
    }

    // MARK: - Create Panel
    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.identifier = NSUserInterfaceItemIdentifier("PathAutoCompletePanel")
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .normal
        panel.contentView = NSHostingView(rootView: AutoCompletePopupView(model: model))
        self.panel = panel
    }
}

// MARK: - Auto Complete Popup View
private struct AutoCompletePopupView: View {
    let model: AutoCompletePopupModel
    @Namespace private var selectionNamespace

    private enum Layout {
        static let cornerRadius: CGFloat = 14
        static let rowCornerRadius: CGFloat = 8
        static let horizontalPadding: CGFloat = 8
        static let rowHeight: CGFloat = 34
        static let recentSeparatorHeight: CGFloat = 7
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            suggestions
            Divider().opacity(0.55)
            footer
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .padding(1)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
            Text(L10n.PathInput.folders)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text(L10n.PathInput.resultsCount(model.items.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    private var suggestions: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0, model.items[index - 1].isRecent, !item.isRecent {
                            Rectangle()
                                .fill(.primary.opacity(0.16))
                                .frame(height: 1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                        }
                        AutoCompletePopupRow(
                            item: item,
                            isSelected: index == model.selectedIndex,
                            selectionNamespace: selectionNamespace,
                            onAccept: { model.acceptItem(id: item.id) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, Layout.horizontalPadding)
            }
            .onChange(of: model.selectedIndex) { _, index in
                guard model.items.indices.contains(index) else { return }
                proxy.scrollTo(model.items[index].id, anchor: .center)
            }
            .onChange(of: model.items) { _, items in
                guard items.indices.contains(model.selectedIndex) else { return }
                proxy.scrollTo(items[model.selectedIndex].id, anchor: .top)
            }
        }
        .frame(
            height: CGFloat(min(model.items.count, 8)) * Layout.rowHeight
                + 8
                + (hasRecentSeparator ? Layout.recentSeparatorHeight : 0)
        )
    }

    private var hasRecentSeparator: Bool {
        model.items.contains(where: \.isRecent) && model.items.contains { !$0.isRecent }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            keyHint("↑↓", label: L10n.PathInput.select)
            keyHint("⇥", label: L10n.PathInput.complete)
            keyHint("↩", label: L10n.PathInput.open)
            Spacer()
            keyHint("esc", label: L10n.Button.cancel)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .foregroundStyle(.secondary)
    }

    // MARK: - Key Hint
    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10.5, weight: .medium, design: .default))
                .padding(.horizontal, 5)
                .frame(minHeight: 18)
                .background(.primary.opacity(0.07), in: .rect(cornerRadius: 5))
            Text(label)
                .font(.caption2)
        }
    }
}
