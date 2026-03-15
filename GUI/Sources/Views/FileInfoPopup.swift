// FileInfoPopup.swift
// MiMiNavigator
//
// Created by Claude on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal mini-popup showing full file information on L-click
//              when the file name is truncated. NSPanel-based, light yellow
//              background, thin crisp fonts in black/dark-navy.
//              Text is selectable for copy. Dismisses on focus loss or ESC.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - FileInfoPopupModifier
/// Tracks truncation state and anchor position for the name column.
/// Does NOT add any gesture recognizers — popup is triggered externally
/// via FileInfoPopupController.shared.showIfTruncated() from FileRow's
/// existing single-click handler to avoid gesture conflicts with drag-drop.
struct FileInfoPopupModifier: ViewModifier {
    let file: CustomFile

    @State private var isTruncated = false
    @State private var anchorFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(truncationDetector)
            .background(anchorTracker)
            .onHover { hovering in
                if hovering && isTruncated {
                    FileInfoPopupController.shared.registerTruncatedFile(
                        file: file, anchorFrame: anchorFrame
                    )
                } else if !hovering {
                    FileInfoPopupController.shared.clearRegistration()
                }
            }
    }

    private var truncationDetector: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { checkTruncation(availableWidth: geo.size.width) }
                .onChange(of: geo.size.width) { _, newWidth in
                    checkTruncation(availableWidth: newWidth)
                }
        }
    }

    private var anchorTracker: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { anchorFrame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                    anchorFrame = newFrame
                }
        }
    }

    private func checkTruncation(availableWidth: CGFloat) {
        let nsFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let textWidth = (file.nameStr as NSString).size(withAttributes: [.font: nsFont]).width
        isTruncated = textWidth > availableWidth
    }
}

// MARK: - View Extension
extension View {
    func fileInfoPopup(file: CustomFile) -> some View {
        modifier(FileInfoPopupModifier(file: file))
    }
}

// MARK: - FileInfoPopupController
/// Singleton NSPanel controller for file info popup.
/// Light yellow HUD with thin crisp black/navy text, fully selectable.
@MainActor
final class FileInfoPopupController {
    static let shared = FileInfoPopupController()
    private var panel: NSPanel?
    private var textView: NSTextView?
    nonisolated(unsafe) private var clickOutsideMonitor: Any?
    nonisolated(unsafe) private var escKeyMonitor: Any?
    nonisolated(unsafe) private var focusMonitor: Any?

    private init() {}

    // MARK: - Registered truncated file (set by hover, consumed by click)
    private var registeredFile: CustomFile?
    private var registeredAnchorFrame: CGRect = .zero

    /// Called by FileInfoPopupModifier on hover when name is truncated
    func registerTruncatedFile(file: CustomFile, anchorFrame: CGRect) {
        registeredFile = file
        registeredAnchorFrame = anchorFrame
    }

    /// Called by FileInfoPopupModifier when hover ends
    func clearRegistration() {
        registeredFile = nil
        registeredAnchorFrame = .zero
    }

    /// Called from FileRow.handleSingleClick() — shows popup only if a
    /// truncated file was registered by hover on the name column.
    func showIfTruncated(for file: CustomFile) {
        guard let reg = registeredFile, reg.id == file.id else { return }
        show(file: reg, anchorFrame: registeredAnchorFrame)
    }

    // MARK: - Colors
    /// Light warm yellow — reminiscent of classic sticky-note tooltips
    private static let bgColor = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.88, alpha: 0.97)
    /// Black for primary info
    private static let primaryColor = NSColor.black
    /// Dark navy for labels
    private static let labelColor = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.38, alpha: 1.0)
    /// Thin crisp system font
    private static let valueFont = NSFont.systemFont(ofSize: 11.5, weight: .light)
    private static let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private static let nameFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)

    // MARK: - Show
    func show(file: CustomFile, anchorFrame: CGRect) {
        if panel == nil { createPanel() }
        guard let panel, let textView, let window = NSApp.keyWindow else { return }
        let attributed = buildContent(for: file)
        textView.textStorage?.setAttributedString(attributed)
        let textWidth: CGFloat = 320
        textView.frame.size.width = textWidth - 20
        textView.sizeToFit()
        let textHeight = textView.frame.height
        let panelWidth = textWidth
        let panelHeight = min(textHeight + 20, 300)
        let windowHeight = window.frame.height
        let appKitX = anchorFrame.minX
        let appKitY = windowHeight - anchorFrame.maxY
        let pointInScreen = window.convertPoint(toScreen: NSPoint(x: appKitX, y: appKitY))
        let targetFrame = NSRect(
            x: pointInScreen.x,
            y: pointInScreen.y - panelHeight - 4,
            width: panelWidth,
            height: panelHeight
        )
        if panel.isVisible {
            panel.setFrame(targetFrame, display: true)
            return
        }
        let startFrame = NSRect(
            x: targetFrame.origin.x,
            y: targetFrame.origin.y + 6,
            width: targetFrame.width,
            height: targetFrame.height
        )
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    // MARK: - Hide
    func hide() {
        removeMonitors()
        guard let panel, panel.isVisible else { return }
        let parentWindow = panel.parent
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.1
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                Task { @MainActor in
                    parentWindow?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            })
    }

    // MARK: - Build Content
    private func buildContent(for file: CustomFile) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let nameParaStyle = NSMutableParagraphStyle()
        nameParaStyle.lineBreakMode = .byWordWrapping
        nameParaStyle.paragraphSpacing = 6
        result.append(
            NSAttributedString(
                string: file.nameStr + "\n",
                attributes: [
                    .font: Self.nameFont,
                    .foregroundColor: Self.primaryColor,
                    .paragraphStyle: nameParaStyle,
                ]
            ))
        addField(to: result, label: "Path", value: file.pathStr)
        if !file.fileSizeFormatted.isEmpty {
            addField(to: result, label: "Size", value: file.fileSizeFormatted)
        }
        addField(to: result, label: "Kind", value: file.kindFormatted)
        if let date = file.modifiedDate {
            addField(to: result, label: "Modified", value: CustomFile.formatDate(date))
        }
        if let date = file.creationDate {
            addField(to: result, label: "Created", value: CustomFile.formatDate(date))
        }
        let perms = file.permissionsFormatted
        if !perms.isEmpty {
            addField(to: result, label: "Permissions", value: perms)
        }
        let owner = file.ownerFormatted
        if !owner.isEmpty {
            addField(to: result, label: "Owner", value: owner)
        }
        if file.isSymbolicLink {
            let resolved = file.urlValue.resolvingSymlinksInPath().path
            addField(to: result, label: "Link target", value: resolved)
        }
        if let archive = file.archiveSourcePath {
            addField(to: result, label: "Archive", value: archive)
        }
        if let internal_ = file.archiveInternalPath {
            addField(to: result, label: "Inside", value: internal_)
        }
        return result
    }

    private func addField(to result: NSMutableAttributedString, label: String, value: String) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineBreakMode = .byWordWrapping
        paraStyle.paragraphSpacing = 2
        paraStyle.headIndent = 0
        result.append(
            NSAttributedString(
                string: label + ": ",
                attributes: [
                    .font: Self.labelFont,
                    .foregroundColor: Self.labelColor,
                    .paragraphStyle: paraStyle,
                ]
            ))
        result.append(
            NSAttributedString(
                string: value + "\n",
                attributes: [
                    .font: Self.valueFont,
                    .foregroundColor: Self.primaryColor,
                    .paragraphStyle: paraStyle,
                ]
            ))
    }

    // MARK: - Create Panel
    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.bgColor.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        container.layer?.borderColor = NSColor(calibratedRed: 0.78, green: 0.74, blue: 0.58, alpha: 0.6).cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.12
        container.layer?.shadowRadius = 8
        container.layer?.shadowOffset = CGSize(width: 0, height: -2)
        p.contentView = container
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = true
        tv.textContainerInset = NSSize(width: 0, height: 0)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        scrollView.documentView = tv
        self.panel = p
        self.textView = tv
    }

    // MARK: - Monitors
    private func installMonitors() {
        removeMonitors()
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            if event.window === panel { return event }
            self.hide()
            return event
        }
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            if event.keyCode == 53 {
                self.hide()
                return nil
            }
            return event
        }
        focusMonitor = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func removeMonitors() {
        if let m = clickOutsideMonitor {
            NSEvent.removeMonitor(m)
            clickOutsideMonitor = nil
        }
        if let m = escKeyMonitor {
            NSEvent.removeMonitor(m)
            escKeyMonitor = nil
        }
        if let m = focusMonitor {
            NotificationCenter.default.removeObserver(m)
            focusMonitor = nil
        }
    }

    deinit {
        let m1 = clickOutsideMonitor
        let m2 = escKeyMonitor
        let m3 = focusMonitor
        if let m = m1 { NSEvent.removeMonitor(m) }
        if let m = m2 { NSEvent.removeMonitor(m) }
        if let m = m3 { NotificationCenter.default.removeObserver(m) }
    }
}
