// PathAutoCompleteField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text field with directory autocomplete suggestions (Finder Go-To-Folder style)

import SwiftUI

// MARK: - Path text field with autocomplete dropdown
struct PathAutoCompleteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = 0

    private let maxSuggestions = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text field
            TextField(L10n.PathInput.placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textContentType(.none)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 6))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    updateSuggestions(for: newValue)
                }
                .onSubmit {
                    // Enter always navigates to the typed path, never applies suggestion
                    showSuggestions = false
                    onSubmit()
                }
                .onExitCommand {
                    if showSuggestions {
                        showSuggestions = false
                    } else {
                        onCancel()
                    }
                }
                .onKeyPress(.downArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = max(selectedIndex - 1, 0)
                    }
                    return .handled
                }
                .onKeyPress(.tab) {
                    if showSuggestions, !suggestions.isEmpty,
                       selectedIndex >= 0, selectedIndex < suggestions.count {
                        applySuggestion(suggestions[selectedIndex])
                    }
                    return .handled
                }
                .onAppear {
                    // Select all text
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }

            // Suggestions popup
            if showSuggestions, !suggestions.isEmpty {
                suggestionsPopup
            }
        }
    }

    // MARK: - Suggestions popup view
    private var suggestionsPopup: some View {
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
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .onChange(of: selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }

    // MARK: - Single suggestion row
    private func suggestionRow(name: String, index: Int) -> some View {
        let isDir = isDirEntry(name)
        return HStack(spacing: 6) {
            Image(systemName: isDir ? "folder.fill" : "doc")
                .font(.system(size: 12))
                .foregroundStyle(isDir ? Color.accentColor : .secondary)
                .frame(width: 16)
            Text(name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            applySuggestion(name)
        }
        .onHover { hovering in
            if hovering { selectedIndex = index }
        }
    }

    // MARK: - Update suggestions based on current text
    private func updateSuggestions(for path: String) {
        guard !path.isEmpty, path.hasPrefix("/") else {
            showSuggestions = false
            suggestions = []
            return
        }

        let url: URL
        let prefix: String

        if path.hasSuffix("/") {
            // List contents of this directory
            url = URL(fileURLWithPath: path)
            prefix = ""
        } else {
            // List contents of parent, filter by typed name
            url = URL(fileURLWithPath: path).deletingLastPathComponent()
            prefix = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            showSuggestions = false
            suggestions = []
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []  // Show all files including hidden
            )
            var matches = contents
                .map(\.lastPathComponent)
                .filter { name in
                    prefix.isEmpty || name.lowercased().hasPrefix(prefix)
                }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            if matches.count > maxSuggestions {
                matches = Array(matches.prefix(maxSuggestions))
            }

            suggestions = matches
            selectedIndex = 0
            showSuggestions = !matches.isEmpty
        } catch {
            log.verbose("Autocomplete scan failed for \(url.path): \(error.localizedDescription)")
            suggestions = []
            showSuggestions = false
        }
    }

    // MARK: - Apply selected suggestion
    private func applySuggestion(_ name: String) {
        let basePath: String
        if text.hasSuffix("/") {
            basePath = text
        } else {
            basePath = (text as NSString).deletingLastPathComponent
            + (text.contains("/") ? "/" : "")
        }
        let newPath = basePath + name

        // If it's a directory, append "/" to continue browsing
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir), isDir.boolValue {
            text = newPath + "/"
        } else {
            text = newPath
            showSuggestions = false
        }
        // Keep updating suggestions for the new path
        updateSuggestions(for: text)
    }

    // MARK: - Check if entry is a directory
    private func isDirEntry(_ name: String) -> Bool {
        let basePath: String
        if text.hasSuffix("/") {
            basePath = text
        } else {
            basePath = (text as NSString).deletingLastPathComponent + "/"
        }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: basePath + name, isDirectory: &isDir) && isDir.boolValue
    }
}
