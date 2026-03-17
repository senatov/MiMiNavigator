// FileInfoPopup.swift
// MiMiNavigator
//
// Created by Claude on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal mini-popup showing full file information.
//              NSPanel-based, light yellow, thin crisp black/dark-navy fonts.
//              Text is selectable for copy. Dismisses on focus loss or ESC.
//
//              Trigger: small orange triangle button at the right edge of
//              the Name column, visible only when the row is selected AND
//              the file name is truncated.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - FileInfoButton
/// Small orange triangle button at the right edge of Name column.
/// Visible when the row is selected AND the file name is truncated.
/// Works for all types: files, directories, symlinks, bundles, archives.
struct FileInfoButton: View {
    let file: CustomFile
    let isSelected: Bool

    @State private var isTruncated = false
    @State private var anchorFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    anchorFrame = geo.frame(in: .global)
                    checkTruncation(width: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, w in checkTruncation(width: w) }
                .onChange(of: geo.frame(in: .global)) { _, f in anchorFrame = f }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            if isSelected && isTruncated {
                Button {
                    FileInfoPopupController.shared.show(
                        file: file, anchorFrame: anchorFrame
                    )
                } label: {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .padding(.trailing, 1)
                }
                .buttonStyle(.plain)
                .help("File Info")
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
                .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
    }

    private func checkTruncation(width: CGFloat) {
        let nsFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let textWidth = (file.nameStr as NSString).size(withAttributes: [.font: nsFont]).width
        isTruncated = textWidth > width
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
    private var monitors = PopupEventMonitors()

    private init() {}

    // MARK: - Colors
    private static let bgColor = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.88, alpha: 0.97)
    private static let primaryColor = NSColor.black
    private static let labelColor = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.38, alpha: 1.0)
    private static let valueFont = NSFont.systemFont(ofSize: 11.5, weight: .light)
    private static let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private static let nameFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)

    // MARK: - Date formatter
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()

    // MARK: - Show
    func show(file: CustomFile, anchorFrame: CGRect) {
        if panel == nil { createPanel() }
        guard let panel, let textView, let window = NSApp.keyWindow else { return }
        let attributed = buildContent(for: file)
        textView.textStorage?.setAttributedString(attributed)
        let textWidth: CGFloat = 340
        textView.frame.size.width = textWidth - 20
        textView.sizeToFit()
        let textHeight = textView.frame.height
        let panelWidth = textWidth
        let panelHeight = min(textHeight + 20, 360)
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
            textView.textStorage?.setAttributedString(attributed)
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
        monitors.install(panel: panel) { [weak self] in self?.hide() }
    }

    // MARK: - Hide
    func hide() {
        monitors.remove()
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
        result.append(NSAttributedString(
            string: file.nameStr + "\n",
            attributes: [
                .font: Self.nameFont,
                .foregroundColor: Self.primaryColor,
                .paragraphStyle: nameParaStyle,
            ]
        ))
        addField(to: result, label: "Path", value: file.pathStr)
        // Type description
        var typeDesc = file.kindFormatted
        if file.isAppBundle { typeDesc = "Application Bundle" }
        else if file.isSymbolicDirectory { typeDesc = "Symbolic Link → Folder" }
        else if file.isSymbolicLink { typeDesc = "Symbolic Link" }
        else if file.isDirectory { typeDesc = "Folder" }
        else if file.isArchiveFile { typeDesc = "Archive (\(file.fileExtension.uppercased()))" }
        addField(to: result, label: "Kind", value: typeDesc)
        // Size
        if !file.fileSizeFormatted.isEmpty {
            addField(to: result, label: "Size", value: file.fileSizeFormatted)
        } else if let cached = file.cachedAppSize, cached > 0 {
            addField(to: result, label: "Size", value: CustomFile.formatBytes(cached))
        }
        // Child count for directories
        if file.isDirectory, let count = file.cachedChildCount, count >= 0 {
            addField(to: result, label: "Items", value: "\(count)")  
        }
        // Fetch all dates directly from the file system
        let dates = fetchDates(for: file.urlValue)
        if let d = dates.modified { addField(to: result, label: "Modified", value: Self.dateFormatter.string(from: d)) }
        if let d = dates.created { addField(to: result, label: "Created", value: Self.dateFormatter.string(from: d)) }
        if let d = dates.lastOpened { addField(to: result, label: "Last Opened", value: Self.dateFormatter.string(from: d)) }
        if let d = dates.added { addField(to: result, label: "Date Added", value: Self.dateFormatter.string(from: d)) }
        if let d = dates.lastUsed { addField(to: result, label: "Last Used", value: Self.dateFormatter.string(from: d)) }
        let perms = file.permissionsFormatted
        if !perms.isEmpty { addField(to: result, label: "Permissions", value: perms) }
        let owner = file.ownerFormatted
        if !owner.isEmpty { addField(to: result, label: "Owner", value: owner) }
        if file.isSymbolicLink {
            addField(to: result, label: "Link target", value: file.urlValue.resolvingSymlinksInPath().path)
        }
        if let archive = file.archiveSourcePath { addField(to: result, label: "Archive", value: archive) }
        if let internal_ = file.archiveInternalPath { addField(to: result, label: "Inside", value: internal_) }
        return result
    }

    // MARK: - Fetch dates from file system
    private struct FileDates {
        var created: Date?
        var modified: Date?
        var lastOpened: Date?
        var added: Date?
        var lastUsed: Date?
    }

    private func fetchDates(for url: URL) -> FileDates {
        let keys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .addedToDirectoryDateKey,
        ]
        guard let vals = try? url.resourceValues(forKeys: keys) else {
            return FileDates()
        }
        // MDItem for "last used" date (Spotlight metadata)
        var lastUsed: Date?
        if let mdItem = MDItemCreateWithURL(nil, url as CFURL) {
            if let val = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) {
                lastUsed = val as? Date
            }
        }
        return FileDates(
            created: vals.creationDate,
            modified: vals.contentModificationDate,
            lastOpened: vals.contentAccessDate,
            added: vals.addedToDirectoryDate,
            lastUsed: lastUsed
        )
    }

    private func addField(to result: NSMutableAttributedString, label: String, value: String) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineBreakMode = .byWordWrapping
        paraStyle.paragraphSpacing = 2
        result.append(NSAttributedString(
            string: label + ": ",
            attributes: [.font: Self.labelFont, .foregroundColor: Self.labelColor, .paragraphStyle: paraStyle]
        ))
        result.append(NSAttributedString(
            string: value + "\n",
            attributes: [.font: Self.valueFont, .foregroundColor: Self.primaryColor, .paragraphStyle: paraStyle]
        ))
    }

    // MARK: - Create Panel
    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
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

}
