//
//  FileRow+Columns.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Column cell renderers used by FileRow — KindCell and PermissionsCell.
//               Extracted from FileRow.swift for single-responsibility.

import AppKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

    // MARK: - Kind column cell
    /// HIG-26: folder outline weight .light, archive = icon+abbrev, alias = arrow
    // MARK: - KindCell
struct KindCell: View {
        let file: CustomFile

        var body: some View {
            if file.isDirectory || file.isSymbolicDirectory {
                Image(systemName: file.isSymbolicDirectory ? "folder.badge.questionmark" : "folder")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 12, weight: .light))
                    .help(file.isSymbolicDirectory ? "Symbolic Link to Folder" : "Folder")
            } else if file.isSymbolicLink {
                Image(systemName: "arrow.up.right.square")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 12, weight: .light))
                    .help("Symbolic Link")
            } else if file.isArchiveFile {
                HStack(spacing: 3) {
                    Image(systemName: archiveSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 12, weight: .regular))
                    Text(archiveAbbrev)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                }
                .help(fullKindDescription)
            } else {
                Text(shortKind)
                    .help(fullKindDescription)
            }
        }

        private var archiveAbbrev: String {
            let name = file.nameStr.lowercased()
            if name.hasSuffix(".tar.gz") { return "TGZ" }
            if name.hasSuffix(".tar.bz2") { return "TBZ2" }
            if name.hasSuffix(".tar.xz") { return "TXZ" }
            if name.hasSuffix(".tar.lzma") { return "TLZ" }
            if name.hasSuffix(".tar.zst") { return "TZS" }
            if name.hasSuffix(".tar.lz4") { return "TL4" }
            if name.hasSuffix(".tar.lzo") { return "TLO" }
            if name.hasSuffix(".tar.lz") { return "TLZ" }
            let ext = file.fileExtension.uppercased()
            return ext.isEmpty ? "ARC" : ext
        }

        /// SF Symbol for archive icon — colored by format family
        private var archiveSymbol: String {
            let ext = file.fileExtension.lowercased()
            let name = file.nameStr.lowercased()
            // disk images
            if ext == "dmg" || ext == "img" || ext == "iso" { return "internaldrive" }
            // java / android
            if ["jar", "war", "ear", "aar", "apk"].contains(ext) { return "archivebox.fill" }
            // modern compression (zst, lz4, xz, lzma)
            if ["zst", "zstd", "lz4", "xz", "lzma", "txz", "tlz"].contains(ext)
                || name.hasSuffix(".tar.xz") || name.hasSuffix(".tar.lzma")
                || name.hasSuffix(".tar.zst") || name.hasSuffix(".tar.lz4")
            {
                return "shippingbox"
            }
            // bzip2 family
            if ["bz2", "bzip2", "tbz", "tbz2"].contains(ext)
                || name.hasSuffix(".tar.bz2")
            {
                return "shippingbox.fill"
            }
            // gzip / tar.gz
            if ["gz", "tgz", "gzip", "tar"].contains(ext)
                || name.hasSuffix(".tar.gz")
            {
                return "cylinder"
            }
            // 7z
            if ext == "7z" { return "doc.zipper" }
            // zip (default)
            return "zipper.page"
        }

        private var shortKind: String {
            let ext = file.fileExtension.uppercased()
            if ext.isEmpty { return "Doc" }
            if let idx = ext.firstIndex(where: { $0 == "_" || $0 == "-" }) {
                return String(ext[..<idx])
            }
            return ext
        }

        private var fullKindDescription: String {
            let ext = file.fileExtension.lowercased()
            guard !ext.isEmpty else { return "Document" }
            if let uttype = UTType(filenameExtension: ext), let desc = uttype.localizedDescription {
                return desc
            }
            return ext.uppercased()
        }
    }

    // MARK: - PermissionsCell
struct PermissionsCell: View {
        let permissions: String

        var body: some View {
            Text(permissions)
                .help(octalValue)
        }

        /// Convert symbolic permissions (rwxr-xr-x) to octal (755)
        private var octalValue: String {
            let chars = Array(permissions)
            guard chars.count >= 9 else { return permissions }
            // Take last 9 characters (skip type indicator like 'd' or '-')
            let permChars = chars.suffix(9)
            guard permChars.count == 9 else { return permissions }
            let arr = Array(permChars)
            let owner = tripletToOctal(arr[0], arr[1], arr[2])
            let group = tripletToOctal(arr[3], arr[4], arr[5])
            let other = tripletToOctal(arr[6], arr[7], arr[8])
            return "\(owner)\(group)\(other)"
        }

        /// Convert rwx triplet to octal digit (0-7)
        private func tripletToOctal(_ r: Character, _ w: Character, _ x: Character) -> Int {
            var value = 0
            if r == "r" { value += 4 }
            if w == "w" { value += 2 }
            if x == "x" || x == "s" || x == "t" { value += 1 }
            return value
        }
    }
