// FileInfoPopup.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: File metadata HUD popup.
//   FileInfoButton  — small orange ▶ trigger shown on selected+truncated row.
//   FileInfoPopupController — inherits all panel/show/hide from InfoPopupController,
//   only owns buildContent(for:) and date fetching.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - FileInfoButton
/// Orange triangle at right edge of Name column.
/// Visible when row is selected AND file name is truncated.
struct FileInfoButton: View {
    let file: CustomFile
    let isSelected: Bool

    @State private var isTruncated  = false
    @State private var anchorFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    anchorFrame = geo.frame(in: .global)
                    checkTruncation(width: geo.size.width)
                }
                .onChange(of: geo.size.width)           { _, w in checkTruncation(width: w) }
                .onChange(of: geo.frame(in: .global))   { _, f in anchorFrame = f }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            if isSelected && isTruncated {
                Button {
                    FileInfoPopupController.shared.show(file: file, anchorFrame: anchorFrame)
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
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        isTruncated = (file.nameStr as NSString).size(withAttributes: [.font: font]).width > width
    }
}

// MARK: - FileInfoPopupController
@MainActor
final class FileInfoPopupController: InfoPopupController {

    static let shared = FileInfoPopupController()
    private override init() { super.init() }

    // MARK: - Date formatter
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()

    // MARK: - show(file:anchorFrame:)
    func show(file: CustomFile, anchorFrame: CGRect) {
        show(content: buildContent(for: file), anchorFrame: anchorFrame, width: 340)
    }

    // MARK: - buildContent
    private func buildContent(for file: CustomFile) -> NSAttributedString {
        let out  = NSMutableAttributedString()
        let para = defaultPara(spacing: 2)
        let titlePara = defaultPara(spacing: 6)

        out.appendHUD(file.nameStr + "\n", font: Self.nameFont, color: Self.valueColor, para: titlePara)

        out.appendField(label: "Path",  value: file.pathStr, para: para)

        var kind = file.kindFormatted
        if      file.isAppBundle        { kind = "Application Bundle" }
        else if file.isSymbolicDirectory { kind = "Symbolic Link → Folder" }
        else if file.isSymbolicLink     { kind = "Symbolic Link" }
        else if file.isDirectory        { kind = "Folder" }
        else if file.isArchiveFile      { kind = "Archive (\(file.fileExtension.uppercased()))" }
        out.appendField(label: "Kind", value: kind, para: para)

        if !file.fileSizeFormatted.isEmpty {
            out.appendField(label: "Size", value: file.fileSizeFormatted, para: para)
        } else if let cached = file.cachedAppSize, cached > 0 {
            out.appendField(label: "Size", value: CustomFile.formatBytes(cached), para: para)
        }
        if file.isDirectory, let count = file.cachedChildCount, count >= 0 {
            out.appendField(label: "Items", value: "\(count)", para: para)
        }

        let dates = fetchDates(for: file.urlValue)
        if let d = dates.modified    { out.appendField(label: "Modified",    value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.created     { out.appendField(label: "Created",     value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.lastOpened  { out.appendField(label: "Last Opened", value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.added       { out.appendField(label: "Date Added",  value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.lastUsed    { out.appendField(label: "Last Used",   value: Self.dateFmt.string(from: d), para: para) }

        let perms = file.permissionsFormatted
        if !perms.isEmpty { out.appendField(label: "Permissions", value: perms, para: para) }
        let owner = file.ownerFormatted
        if !owner.isEmpty { out.appendField(label: "Owner", value: owner, para: para) }

        if file.isSymbolicLink {
            out.appendField(label: "Link target", value: file.urlValue.resolvingSymlinksInPath().path, para: para)
        }
        if let arch = file.archiveSourcePath    { out.appendField(label: "Archive", value: arch, para: para) }
        if let int_ = file.archiveInternalPath  { out.appendField(label: "Inside",  value: int_, para: para) }

        return out
    }

    // MARK: - Dates
    private struct FileDates {
        var created: Date?; var modified: Date?
        var lastOpened: Date?; var added: Date?; var lastUsed: Date?
    }

    private func fetchDates(for url: URL) -> FileDates {
        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey,
            .contentAccessDateKey, .addedToDirectoryDateKey,
        ]
        guard let vals = try? url.resourceValues(forKeys: keys) else { return FileDates() }
        var lastUsed: Date?
        if let mdItem = MDItemCreateWithURL(nil, url as CFURL),
           let val = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) {
            lastUsed = val as? Date
        }
        return FileDates(
            created:    vals.creationDate,
            modified:   vals.contentModificationDate,
            lastOpened: vals.contentAccessDate,
            added:      vals.addedToDirectoryDate,
            lastUsed:   lastUsed
        )
    }

    // MARK: - Para helper
    private func defaultPara(spacing: CGFloat) -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode    = .byWordWrapping
        p.paragraphSpacing = spacing
        return p
    }
}
