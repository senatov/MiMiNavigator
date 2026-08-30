// PathAutoCompleteField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text field with directory autocomplete — NSPanel-based dropdown + inline ghost completion.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Path Auto Complete Field
struct PathAutoCompleteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let recentDirectories: () -> [URL]
    let onNavigate: (String) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var suggestions: [AutoCompleteItem] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = 0
    @State private var ghostSuffix: String = ""
    @State private var suppressOnChange = false
    @State private var popupController = AutoCompletePopupController()
    @State private var suggestionTask: Task<Void, Never>?

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
                    dismissPopup()
                    onCancel()
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
                    suggestionTask?.cancel()
                    popupController.hide()
                }
        }
    }

    // MARK: - Update Suggestions
    private func updateSuggestions(for path: String) {
        suggestionTask?.cancel()
        guard let resolvedPath = expandedPath(path),
              isValidAbsolutePath(resolvedPath)
        else {
            dismissPopup()
            return
        }
        let showHidden = UserPreferences.shared.snapshot.showHiddenFiles
        suggestionTask = Task {
            let result = await Self.scanSuggestions(
                displayPath: path,
                resolvedPath: resolvedPath,
                showHidden: showHidden
            )
            guard !Task.isCancelled, text == path else { return }
            guard let result else {
                dismissPopup()
                return
            }
            let directoryURL = URL(fileURLWithPath: result.directoryPath)
            applySuggestions(result.matches, prefix: result.prefix, directoryURL: directoryURL)
        }
    }

    private func isValidAbsolutePath(_ path: String) -> Bool {
        !path.isEmpty && path.hasPrefix("/")
    }

    private func expandedPath(_ path: String) -> String? {
        guard let resolved = PathEnvironmentResolver.expand(path) else { return nil }
        return (resolved.expanded as NSString).expandingTildeInPath
    }

    private func applySuggestions(_ matches: [String], prefix: String, directoryURL: URL) {
        let recentItems = recentDirectories().map {
            AutoCompleteItem(
                file: CustomFile(name: $0.lastPathComponent, path: $0.path),
                section: .recent,
                matchPrefix: ""
            )
        }
        let childItems = matches.map {
            let url = directoryURL.appendingPathComponent($0)
            return AutoCompleteItem(
                file: CustomFile(name: $0, path: url.path),
                section: .subdirectory,
                matchPrefix: prefix
            )
        }
        let items = recentItems + childItems
        log.debug(
            "[PathAutoComplete] suggestions base='\(directoryURL.path)' prefix='\(prefix)' recent=\(recentItems.count) children=\(childItems.count)"
        )
        suggestions = items
        selectedIndex = 0
        showSuggestions = !items.isEmpty

        updateGhostFromSelection()

        if showSuggestions {
            popupController.show(
                items: items,
                selectedIndex: 0,
                onHighlight: { idx in
                    guard suggestions.indices.contains(idx) else { return }
                    selectedIndex = idx
                    updateGhostFromSelection()
                },
                onSelect: { item in
                    drillIntoSuggestion(path: item.file.pathStr)
                }
            )
        } else {
            popupController.hide()
        }
    }

    // MARK: - Accept Completion
    private func acceptCompletion() {
        if showSuggestions, !suggestions.isEmpty,
            selectedIndex >= 0, selectedIndex < suggestions.count
        {
            popupController.acceptSelectedRow()
        }
    }

    // MARK: - Drill Into Suggestion
    private func drillIntoSuggestion(path: String) {
        log.debug("[PathAutoComplete] drilling into path='\(path)'")
        let completedPath = path.hasSuffix("/") ? path : path + "/"
        suppressOnChange = true
        text = completedPath
        suppressOnChange = false
        onNavigate(completedPath)
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
        if selected.isRecent {
            ghostSuffix = ""
        } else if prefix.isEmpty {
            ghostSuffix = selected.name
        } else if selected.name.lowercased().hasPrefix(prefix.lowercased()) {
            ghostSuffix = String(selected.name.dropFirst(prefix.count))
        } else {
            ghostSuffix = ""
        }
    }

    // MARK: - Helpers
    private func splitDisplayPathAndPrefix(_ path: String) -> (directory: String, prefix: String) {
        if path.hasSuffix("/") {
            return (path == "/" ? "/" : String(path.dropLast()), "")
        }

        let nsPath = path as NSString
        let directory = nsPath.deletingLastPathComponent
        return (directory == "." ? "" : directory, nsPath.lastPathComponent)
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
}

// MARK: - Suggestion Scan
private extension PathAutoCompleteField {
    struct SuggestionScanResult: Sendable {
        let directoryPath: String
        let prefix: String
        let matches: [String]
    }

    nonisolated static func scanSuggestions(
        displayPath: String,
        resolvedPath: String,
        showHidden: Bool
    ) async -> SuggestionScanResult? {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let exactURL = URL(fileURLWithPath: resolvedPath)
            let browseExactDirectory = displayPath.hasSuffix("/") || isDirectory(exactURL, fileManager: fileManager)
            let directoryURL = browseExactDirectory ? exactURL : exactURL.deletingLastPathComponent()
            let prefix = browseExactDirectory || displayPath.hasSuffix("/")
                ? ""
                : (displayPath as NSString).lastPathComponent
            guard isDirectory(directoryURL, fileManager: fileManager) else { return nil }
            do {
                let contents = try directoryContents(at: directoryURL, fileManager: fileManager)
                var matches: [String] = []
                for url in contents {
                    guard !Task.isCancelled else { return nil }
                    let name = url.lastPathComponent
                    guard (showHidden || !name.hasPrefix(".")),
                          (prefix.isEmpty
                              || name.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil),
                          isDirectory(url, fileManager: fileManager)
                    else { continue }
                    matches.append(name)
                }
                matches.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                return SuggestionScanResult(
                    directoryPath: directoryURL.path,
                    prefix: prefix,
                    matches: matches
                )
            } catch {
                log.verbose("[PathAutoComplete] scan failed: \(error.localizedDescription)")
                return nil
            }
        }.value
    }

    nonisolated static func directoryContents(at url: URL, fileManager: FileManager) throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            let nsError = error as NSError
            guard nsError.code == NSFileReadNoPermissionError else { throw error }
            let names = try fileManager.contentsOfDirectory(atPath: url.path)
            log.debug("[PathAutoComplete] metadata prefetch denied, using name-only fallback: \(url.path)")
            return names.map { url.appendingPathComponent($0) }
        }
    }

    nonisolated static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            return true
        }
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
