// PathAutoCompleteField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text field with directory autocomplete — dropdown popup + inline ghost completion.

import SwiftUI

// MARK: - Path Auto Complete Field
/// Text field with directory path autocomplete.
/// Features: dropdown suggestion popup (overlay, not inline VStack), inline ghost text completion,
/// Tab to accept ghost/selected suggestion, arrow keys to navigate, Escape to dismiss.
struct PathAutoCompleteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = 0
    /// Ghost completion text shown inline after the cursor (gray, not yet applied)
    @State private var ghostSuffix: String = ""
    /// Guard to prevent onChange firing from our own programmatic text mutations
    @State private var suppressOnChange = false

    private let maxSuggestions = 15

    // MARK: - Body
    var body: some View {
        textFieldLayer
            .overlay(alignment: .topLeading) {
                if showSuggestions, !suggestions.isEmpty {
                    suggestionsOverlay
                        .offset(y: 32)
                }
            }
    }

    // MARK: - Text Field Layer
    private var textFieldLayer: some View {
        ZStack(alignment: .leading) {
            // Ghost text overlay — shows inline completion hint
            if !ghostSuffix.isEmpty {
                Text(text + ghostSuffix)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.5))
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
                    showSuggestions = false
                    ghostSuffix = ""
                    onSubmit()
                }
                .onExitCommand {
                    if showSuggestions {
                        showSuggestions = false
                        ghostSuffix = ""
                    } else {
                        onCancel()
                    }
                }
                .onKeyPress(.downArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
                        updateGhostFromSelection()
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = max(selectedIndex - 1, 0)
                        updateGhostFromSelection()
                    }
                    return .handled
                }
                .onKeyPress(.tab) {
                    acceptCompletion()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    // Right arrow at end of text accepts ghost completion (like Fish shell)
                    if !ghostSuffix.isEmpty {
                        acceptCompletion()
                        return .handled
                    }
                    return .ignored
                }
                .onAppear {
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }
        }
    }

    // MARK: - Suggestions Overlay
    private var suggestionsOverlay: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, name in
                        suggestionRow(name: name, index: index)
                            .id(index)
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .onChange(of: selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }

    // MARK: - Single Suggestion Row
    private func suggestionRow(name: String, index: Int) -> some View {
        let isDir = isDirEntry(name)
        return HStack(spacing: 6) {
            Image(systemName: isDir ? "folder.fill" : "doc")
                .font(.system(size: 12))
                .foregroundStyle(isDir ? Color.accentColor : .secondary)
                .frame(width: 16)
            Text(highlightedName(name))
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if isDir {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            applySuggestion(name)
        }
        .onHover { hovering in
            if hovering {
                selectedIndex = index
                updateGhostFromSelection()
            }
        }
    }

    // MARK: - Highlighted Name (bold the matching prefix)
    private func highlightedName(_ name: String) -> AttributedString {
        let prefix = currentPrefix()
        var attr = AttributedString(name)
        if !prefix.isEmpty,
           let range = attr.range(of: prefix, options: [.caseInsensitive, .anchored])
        {
            attr[range].font = .system(size: 13, weight: .bold)
        }
        return attr
    }

    // MARK: - Update Suggestions
    private func updateSuggestions(for path: String) {
        guard !path.isEmpty, path.hasPrefix("/") else {
            hideSuggestions()
            return
        }
        let (dirURL, prefix) = splitPathAndPrefix(path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: dirURL.path) else {
            hideSuggestions()
            return
        }
        do {
            let contents = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            var matches = contents
                .map(\.lastPathComponent)
                .filter { name in
                    prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased())
                }
                .sorted { lhs, rhs in
                    // Directories first, then alphabetical
                    let lDir = isDirAtURL(dirURL.appendingPathComponent(lhs))
                    let rDir = isDirAtURL(dirURL.appendingPathComponent(rhs))
                    if lDir != rDir { return lDir }
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
            if matches.count > maxSuggestions {
                matches = Array(matches.prefix(maxSuggestions))
            }
            suggestions = matches
            selectedIndex = 0
            showSuggestions = !matches.isEmpty
            updateGhostFromSelection()
        } catch {
            log.verbose("[PathAutoComplete] scan failed: \(error.localizedDescription)")
            hideSuggestions()
        }
    }

    // MARK: - Accept Completion (Tab / Right Arrow)
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
        let (dirURL, _) = splitPathAndPrefix(text)
        let fullPath = dirURL.appendingPathComponent(name).path
        suppressOnChange = true
        if isDirAtURL(URL(fileURLWithPath: fullPath)) {
            text = fullPath + "/"
        } else {
            text = fullPath
            showSuggestions = false
        }
        ghostSuffix = ""
        suppressOnChange = false
        updateSuggestions(for: text)
    }

    // MARK: - Update Ghost From Selection
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
            // Preserve original casing from filesystem
            ghostSuffix = String(selected.dropFirst(prefix.count))
        } else {
            ghostSuffix = ""
        }
    }

    // MARK: - Hide Suggestions
    private func hideSuggestions() {
        showSuggestions = false
        suggestions = []
        ghostSuffix = ""
    }

    // MARK: - Helpers

    /// Split typed text into directory URL and partial name prefix
    private func splitPathAndPrefix(_ path: String) -> (URL, String) {
        if path.hasSuffix("/") {
            return (URL(fileURLWithPath: path), "")
        } else {
            let url = URL(fileURLWithPath: path)
            return (url.deletingLastPathComponent(), url.lastPathComponent)
        }
    }

    /// Current partial name being typed (after last "/")
    private func currentPrefix() -> String {
        splitPathAndPrefix(text).1
    }

    /// Check if path is a directory
    private func isDirAtURL(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Check if suggestion entry is a directory (relative to current base)
    private func isDirEntry(_ name: String) -> Bool {
        let (dirURL, _) = splitPathAndPrefix(text)
        return isDirAtURL(dirURL.appendingPathComponent(name))
    }
}
