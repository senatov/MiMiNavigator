// PreviewDisplayModeStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent per-extension display rules for the embedded panel Preview.

import Foundation
import UniformTypeIdentifiers

// MARK: - Preview Display Mode
enum PreviewDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case quickLook
    case text
    case binary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickLook: return "Quick Look"
        case .text: return "Text"
        case .binary: return "Binary"
        }
    }

    var symbol: String {
        switch self {
        case .quickLook: return "eye"
        case .text: return "doc.plaintext"
        case .binary: return "number"
        }
    }
}

// MARK: - Preview Display Mode Store
@MainActor
@Observable
final class PreviewDisplayModeStore {
    static let shared = PreviewDisplayModeStore()
    private static let rulesKey = "workspace.preview.extensionRules"
    private(set) var rules: [String: PreviewDisplayMode] = [:]

    private init() {
        let stored = MiMiDefaults.shared.dictionary(forKey: Self.rulesKey) ?? [:]
        rules = stored.reduce(into: [:]) { result, pair in
            if let raw = pair.value as? String, let mode = PreviewDisplayMode(rawValue: raw) {
                result[pair.key] = mode
            }
        }
    }

    // MARK: - Resolve Mode
    func mode(for url: URL) -> PreviewDisplayMode? {
        let key = extensionKey(for: url)
        return rules[key] ?? automaticMode(for: url)
    }

    func automaticMode(for url: URL) -> PreviewDisplayMode? {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .quickLook
        }
        let ext = url.pathExtension.lowercased()
        if Self.textExtensions.contains(ext) { return .text }
        if Self.binaryExtensions.contains(ext) { return .binary }
        if Self.quickLookExtensions.contains(ext) { return .quickLook }
        guard let type = UTType(filenameExtension: ext) else { return nil }
        if type.conforms(to: .text) { return .text }
        if type.conforms(to: .image) || type.conforms(to: .audiovisualContent) || type.conforms(to: .pdf) {
            return .quickLook
        }
        return nil
    }

    // MARK: - Rules
    func extensionKey(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "<no extension>" : ext
    }

    func set(_ mode: PreviewDisplayMode, for url: URL) {
        set(mode, forExtension: extensionKey(for: url))
    }

    func set(_ mode: PreviewDisplayMode, forExtension ext: String) {
        rules[normalized(ext)] = mode
        persist()
    }

    func removeRule(forExtension ext: String) {
        rules.removeValue(forKey: normalized(ext))
        persist()
    }

    func removeAllRules() {
        rules.removeAll()
        persist()
    }

    private func normalized(_ ext: String) -> String {
        let clean = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "<no extension>" { return clean }
        return clean.hasPrefix(".") ? String(clean.dropFirst()) : clean
    }

    private func persist() {
        MiMiDefaults.shared.set(rules.mapValues(\.rawValue), forKey: Self.rulesKey)
    }

    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "jsonl", "xml", "fb2", "yaml", "yml",
        "plist", "html", "htm", "css", "js", "ts", "swift", "m", "mm", "h", "hpp", "c", "cpp",
        "java", "kt", "kts", "py", "rb", "php", "sh", "zsh", "fish", "sql", "log", "ini", "conf",
    ]
    private static let binaryExtensions: Set<String> = [
        "bin", "dat", "exe", "dll", "dylib", "so", "o", "a", "class", "wasm",
    ]
    private static let quickLookExtensions: Set<String> = [
        "pdf", "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "svg",
        "mov", "mp4", "m4v", "avi", "mkv", "mp3", "m4a", "aac", "wav", "flac", "doc", "docx",
        "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "zip", "dmg", "pkg",
    ]
}
