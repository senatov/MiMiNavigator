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
    var onSelect: ((Int) -> Void)?

    // MARK: - Select Row
    func selectRow(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
    }

    // MARK: - Accept Row
    func acceptRow(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        onSelect?(index)
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

    // MARK: - Show
    func show(items: [AutoCompleteItem], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        guard !items.isEmpty else {
            hide()
            return
        }
        model.items = items
        model.selectedIndex = selectedIndex
        model.onSelect = onSelect
        let visibleRows = min(items.count, maxVisibleRows)
        let panelHeight = CGFloat(visibleRows) * rowHeight + popupChromeHeight
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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
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
            installResignObserver: false
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
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
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
        .animation(.spring(duration: 0.22, bounce: 0.08), value: model.items)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
            Text("Folders")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text("\(model.items.count) \(model.items.count == 1 ? "result" : "results")")
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
                        AutoCompletePopupRow(
                            item: item,
                            isSelected: index == model.selectedIndex,
                            selectionNamespace: selectionNamespace,
                            onSelect: { model.selectRow(index) },
                            onAccept: { model.acceptRow(index) }
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, Layout.horizontalPadding)
            }
            .onChange(of: model.selectedIndex) { _, index in
                withAnimation(.easeOut(duration: 0.14)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .frame(height: CGFloat(min(model.items.count, 8)) * Layout.rowHeight + 8)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            keyHint("↑↓", label: "Select")
            keyHint("⇥", label: "Complete")
            keyHint("↩", label: "Open")
            Spacer()
            keyHint("esc", label: "Close")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .foregroundStyle(.secondary)
    }

    // MARK: - Key Hint
    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .frame(minHeight: 18)
                .background(.primary.opacity(0.07), in: .rect(cornerRadius: 5))
            Text(label)
                .font(.caption2)
        }
    }
}

// MARK: - Auto Complete Popup Row
private struct AutoCompletePopupRow: View {
    let item: AutoCompleteItem
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let onSelect: () -> Void
    let onAccept: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            AsyncSmartIconView(file: item.file)
                .frame(width: 18, height: 18)
                .allowsHitTesting(false)
            highlightedName
            Spacer(minLength: 8)
            if isSelected {
                Text("↩")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .contentShape(.rect)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.055))
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onAccept)
        .onTapGesture(count: 1, perform: onSelect)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var highlightedName: some View {
        HStack(spacing: 0) {
            Text(matchedPrefix)
                .fontWeight(.semibold)
            Text(unmatchedSuffix)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private var matchedPrefix: String {
        guard !item.matchPrefix.isEmpty,
              item.name.range(of: item.matchPrefix, options: [.caseInsensitive, .anchored]) != nil
        else { return "" }
        return String(item.name.prefix(item.matchPrefix.count))
    }

    private var unmatchedSuffix: String {
        String(item.name.dropFirst(matchedPrefix.count))
    }
}
