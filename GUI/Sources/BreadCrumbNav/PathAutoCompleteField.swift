// PathAutoCompleteField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text field with directory autocomplete — NSPanel-based dropdown + inline ghost completion.

import AppKit
import SwiftUI

// MARK: - Path Auto Complete Field
struct PathAutoCompleteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = 0
    @State private var ghostSuffix: String = ""
    @State private var suppressOnChange = false
    @State private var popupController = AutoCompletePopupController()

    private let maxSuggestions = 12

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            if !ghostSuffix.isEmpty {
                Text(text + ghostSuffix)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.45))
                    .lineLimit(1)
                    .padding(.leading, 7)
                    .allowsHitTesting(false)
            }
            TextField(L10n.PathInput.placeholder, text: $text)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textContentType(.none)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 6))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    guard !suppressOnChange else { return }
                    updateSuggestions(for: newValue)
                }
                .onSubmit {
                    dismissPopup()
                    onSubmit()
                }
                .onExitCommand {
                    if showSuggestions {
                        dismissPopup()
                    } else {
                        onCancel()
                    }
                }
                .onKeyPress(.downArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
                        updateGhostFromSelection()
                        popupController.selectRow(selectedIndex)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = max(selectedIndex - 1, 0)
                        updateGhostFromSelection()
                        popupController.selectRow(selectedIndex)
                    }
                    return .handled
                }
                .onKeyPress(.tab) {
                    acceptCompletion()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if !ghostSuffix.isEmpty {
                        acceptCompletion()
                        return .handled
                    }
                    return .ignored
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                popupController.anchorFrame = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                popupController.anchorFrame = newFrame
                            }
                    }
                )
                .onAppear {
                    popupController.onDismissedByClickOutside = { [self] in
                        showSuggestions = false
                        suggestions = []
                        ghostSuffix = ""
                    }
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }
                .onDisappear {
                    popupController.hide()
                }
        }
    }

    // MARK: - Update Suggestions
    private func updateSuggestions(for path: String) {
        guard let resolvedPath = expandedPath(path),
              isValidAbsolutePath(resolvedPath)
        else {
            dismissPopup()
            return
        }

        let (dirURL, _) = splitPathAndPrefix(resolvedPath)
        let prefix = splitDisplayPathAndPrefix(path).prefix

        guard directoryExists(dirURL) else {
            dismissPopup()
            return
        }

        do {
            let contents = try loadDirectoryContents(at: dirURL)
            let matches = buildSuggestions(from: contents, prefix: prefix)

            applySuggestions(matches, prefix: prefix)
        } catch {
            log.verbose("[PathAutoComplete] scan failed: \(error.localizedDescription)")
            dismissPopup()
        }
    }

    private func isValidAbsolutePath(_ path: String) -> Bool {
        !path.isEmpty && path.hasPrefix("/")
    }

    private func expandedPath(_ path: String) -> String? {
        guard let resolved = PathEnvironmentResolver.expand(path) else { return nil }
        return (resolved.expanded as NSString).expandingTildeInPath
    }

    private func directoryExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func loadDirectoryContents(at url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
    }

    private func buildSuggestions(from contents: [URL], prefix: String) -> [String] {
        let showHidden = UserPreferences.shared.snapshot.showHiddenFiles

        var result =
            contents
            .filter { isDirAtURL($0) }
            .map(\.lastPathComponent)
            .filter { name in
                if !showHidden && name.hasPrefix(".") { return false }
                return prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased())
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if result.count > maxSuggestions {
            result = Array(result.prefix(maxSuggestions))
        }

        return result
    }

    private func applySuggestions(_ matches: [String], prefix: String) {
        suggestions = matches
        selectedIndex = 0
        showSuggestions = !matches.isEmpty

        updateGhostFromSelection()

        if showSuggestions {
            let items = matches.map {
                AutoCompleteItem(name: $0, isDirectory: true, matchPrefix: prefix)
            }

            popupController.show(items: items, selectedIndex: 0) { idx in
                if idx >= 0, idx < suggestions.count {
                    applySuggestion(suggestions[idx])
                }
            }
        } else {
            popupController.hide()
        }
    }

    // MARK: - Accept Completion
    private func acceptCompletion() {
        if !ghostSuffix.isEmpty {
            suppressOnChange = true
            text = text + ghostSuffix
            ghostSuffix = ""
            suppressOnChange = false
            updateSuggestions(for: text)
        } else if showSuggestions, !suggestions.isEmpty,
            selectedIndex >= 0, selectedIndex < suggestions.count
        {
            applySuggestion(suggestions[selectedIndex])
        }
    }

    // MARK: - Apply Suggestion
    private func applySuggestion(_ name: String) {
        let displayParts = splitDisplayPathAndPrefix(text)
        let fullPath = appendDisplayComponent(name, to: displayParts.directory)
        let resolvedFullPath = expandedPath(fullPath) ?? fullPath
        suppressOnChange = true
        if isDirAtURL(URL(fileURLWithPath: resolvedFullPath)) {
            text = fullPath + "/"
        } else {
            text = fullPath
        }
        ghostSuffix = ""
        suppressOnChange = false
        updateSuggestions(for: text)
    }

    // MARK: - Dismiss
    private func dismissPopup() {
        showSuggestions = false
        suggestions = []
        ghostSuffix = ""
        popupController.hide()
    }

    // MARK: - Ghost
    private func updateGhostFromSelection() {
        guard showSuggestions, !suggestions.isEmpty,
            selectedIndex >= 0, selectedIndex < suggestions.count
        else {
            ghostSuffix = ""
            return
        }
        let selected = suggestions[selectedIndex]
        let prefix = currentPrefix()
        if prefix.isEmpty {
            ghostSuffix = selected
        } else if selected.lowercased().hasPrefix(prefix.lowercased()) {
            ghostSuffix = String(selected.dropFirst(prefix.count))
        } else {
            ghostSuffix = ""
        }
    }

    // MARK: - Helpers
    private func splitDisplayPathAndPrefix(_ path: String) -> (directory: String, prefix: String) {
        if path.hasSuffix("/") {
            return (String(path.dropLast()), "")
        }

        let nsPath = path as NSString
        let directory = nsPath.deletingLastPathComponent
        return (directory == "." ? "" : directory, nsPath.lastPathComponent)
    }

    private func appendDisplayComponent(_ component: String, to directory: String) -> String {
        guard !directory.isEmpty else { return component }
        guard directory != "/" else { return "/" + component }
        return directory + "/" + component
    }

    private func splitPathAndPrefix(_ path: String) -> (URL, String) {
        if path.hasSuffix("/") {
            return (URL(fileURLWithPath: path), "")
        } else {
            let url = URL(fileURLWithPath: path)
            return (url.deletingLastPathComponent(), url.lastPathComponent)
        }
    }

    private func currentPrefix() -> String { splitDisplayPathAndPrefix(text).prefix }

    private func isDirAtURL(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
