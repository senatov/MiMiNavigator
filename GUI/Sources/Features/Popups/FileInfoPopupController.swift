//
//  FileInfoPopupController.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import AppKit
import FileModelKit
import Foundation
import SwiftUI

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
    func buildContent(for file: CustomFile) -> NSAttributedString {
        let out = NSMutableAttributedString()
        appendHeader(out, file)
        appendPath(out, file)
        appendKind(out, file)
        appendSize(out, file)
        appendDates(out, file)
        appendPermissions(out, file)
        appendLinks(out, file)
        return out
    }

    private func appendHeader(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 6)
        out.appendHUD(file.nameStr + "\n", font: Self.nameFont, color: Self.valueColor, para: para)
    }

    private func appendPath(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)
        out.appendField(label: "Path", value: file.pathStr, para: para)
    }

    private func appendKind(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)
        var kind = file.kindFormatted
        if file.isAppBundle {
            kind = "Application Bundle"
        } else if file.isSymbolicDirectory {
            kind = "Symbolic Link → Folder"
        } else if file.isSymbolicLink {
            kind = "Symbolic Link"
        } else if file.isDirectory {
            kind = "Folder"
        } else if file.isArchiveFile {
            kind = "Archive (\(file.fileExtension.uppercased()))"
        }
        out.appendField(label: "Kind", value: kind, para: para)
    }

    private func appendSize(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)

        if !file.fileSizeFormatted.isEmpty {
            out.appendField(label: "Size", value: file.fileSizeFormatted, para: para)
        } else if let cached = file.cachedAppSize, cached > 0 {
            out.appendField(label: "Size", value: CustomFile.formatBytes(cached), para: para)
        }

        if file.isDirectory, let count = file.cachedChildCount, count >= 0 {
            out.appendField(label: "Items", value: "\(count)", para: para)
        }
    }

    private func appendDates(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)
        let dates = fetchDates(for: file.urlValue)

        if let d = dates.modified { out.appendField(label: "Modified", value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.created { out.appendField(label: "Created", value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.lastOpened { out.appendField(label: "Last Opened", value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.added { out.appendField(label: "Date Added", value: Self.dateFmt.string(from: d), para: para) }
        if let d = dates.lastUsed { out.appendField(label: "Last Used", value: Self.dateFmt.string(from: d), para: para) }
    }

    private func appendPermissions(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)

        if !file.permissionsFormatted.isEmpty {
            out.appendField(label: "Permissions", value: file.permissionsFormatted, para: para)
        }

        if !file.ownerFormatted.isEmpty {
            out.appendField(label: "Owner", value: file.ownerFormatted, para: para)
        }

        if !file.ownerFormatted.isEmpty {
            out.appendField(label: "Group", value: file.groupName, para: para)
        }
    }

    private func appendLinks(_ out: NSMutableAttributedString, _ file: CustomFile) {
        let para = defaultPara(spacing: 2)

        if file.isSymbolicLink {
            out.appendField(label: "Link target", value: file.urlValue.resolvingSymlinksInPath().path, para: para)
        }

        if let arch = file.archiveSourcePath {
            out.appendField(label: "Archive", value: arch, para: para)
        }

        if let int_ = file.archiveInternalPath {
            out.appendField(label: "Inside", value: int_, para: para)
        }
    }

    // MARK: - Dates
    private struct FileDates {
        var created: Date?
        var modified: Date?
        var lastOpened: Date?
        var added: Date?
        var lastUsed: Date?
    }

    private func fetchDates(for url: URL) -> FileDates {
        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey,
            .contentAccessDateKey, .addedToDirectoryDateKey,
        ]
        guard let vals = try? url.resourceValues(forKeys: keys) else { return FileDates() }
        var lastUsed: Date?
        if let mdItem = MDItemCreateWithURL(nil, url as CFURL),
            let val = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate)
        {
            lastUsed = val as? Date
        }
        return FileDates(
            created: vals.creationDate,
            modified: vals.contentModificationDate,
            lastOpened: vals.contentAccessDate,
            added: vals.addedToDirectoryDate,
            lastUsed: lastUsed
        )
    }

    // MARK: - Para helper
    private func defaultPara(spacing: CGFloat) -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = .byWordWrapping
        p.paragraphSpacing = spacing
        return p
    }
}
