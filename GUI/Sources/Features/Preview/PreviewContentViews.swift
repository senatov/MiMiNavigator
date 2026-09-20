// PreviewContentViews.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text and hexadecimal content renderers for the embedded panel Preview.

import AppKit
import SwiftUI

// MARK: - Text File Preview
struct TextFilePreview: View {
    let url: URL
    let searchText: String
    let searchStep: Int
    let searchEnabled: Bool
    @Binding var matchCount: Int
    @Binding var activeMatch: Int
    @State private var text = ""
    @State private var error: String?
    @State private var searchIndex: SearchTextMatcher.Index?

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView("Cannot Read Text", systemImage: "doc.badge.exclamationmark", description: Text(error))
            } else {
                ReadOnlyTextView(
                    text: text,
                    searchText: searchText,
                    searchStep: searchStep,
                    searchIndex: searchIndex,
                    matchCount: $matchCount,
                    activeMatch: $activeMatch
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: url) { await load() }
        .task(id: SearchIndexTaskID(url: url, textLength: text.utf16.count, enabled: searchEnabled)) {
            guard searchEnabled, !text.isEmpty else { return }
            let source = text
            searchIndex = await Task.detached(priority: .userInitiated) {
                SearchTextMatcher.Index(source)
            }.value
        }
    }

    private func load() async {
        searchIndex = nil
        let result = await Task.detached(priority: .utility) { () -> Result<String, Error> in
            Result {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let prefix = data.prefix(4 * 1_024 * 1_024)
                let decoded = String(data: prefix, encoding: .utf8)
                    ?? String(data: prefix, encoding: .utf16)
                    ?? String(decoding: prefix, as: UTF8.self)
                return data.count > prefix.count ? decoded + "\n\n— Preview truncated at 4 MB —" : decoded
            }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let value): text = value; error = nil
        case .failure(let failure): text = ""; error = failure.localizedDescription
        }
    }
}

// MARK: - Search Index Task ID
private struct SearchIndexTaskID: Hashable {
    let url: URL
    let textLength: Int
    let enabled: Bool
}

// MARK: - Read-Only Text View
private struct ReadOnlyTextView: NSViewRepresentable {
    let text: String
    let searchText: String
    let searchStep: Int
    let searchIndex: SearchTextMatcher.Index?
    @Binding var matchCount: Int
    @Binding var activeMatch: Int

    final class Coordinator {
        var searchText = ""
        var searchStep = 0
        var searchIndexID: UUID?
        var activeMatch = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.scrollToBeginningOfDocument(nil)
        }
        let queryChanged = context.coordinator.searchText != searchText
        let stepChanged = context.coordinator.searchStep != searchStep
        let indexChanged = context.coordinator.searchIndexID != searchIndex?.id
        guard queryChanged || stepChanged || indexChanged else { return }
        let backwards = !queryChanged && !indexChanged && searchStep < context.coordinator.searchStep
        context.coordinator.searchText = searchText
        context.coordinator.searchStep = searchStep
        context.coordinator.searchIndexID = searchIndex?.id
        highlightMatches(in: textView, coordinator: context.coordinator, backwards: backwards, restart: queryChanged || indexChanged)
    }

    private func highlightMatches(in textView: NSTextView, coordinator: Coordinator, backwards: Bool, restart: Bool) {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
        guard !searchText.isEmpty, let searchIndex else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            updateMatchState(count: 0, active: 0)
            return
        }
        let matches = searchIndex.ranges(for: searchText)
        guard !matches.isEmpty else {
            updateMatchState(count: 0, active: 0)
            return
        }
        if restart {
            coordinator.activeMatch = 0
        } else if backwards {
            coordinator.activeMatch = (coordinator.activeMatch - 1 + matches.count) % matches.count
        } else {
            coordinator.activeMatch = (coordinator.activeMatch + 1) % matches.count
        }
        for match in matches {
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.32), range: match)
        }
        let match = matches[coordinator.activeMatch]
        textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.systemOrange.withAlphaComponent(0.62), range: match)
        textView.setSelectedRange(match)
        textView.scrollRangeToVisible(match)
        updateMatchState(count: matches.count, active: coordinator.activeMatch)
    }

    private func updateMatchState(count: Int, active: Int) {
        DispatchQueue.main.async {
            if matchCount != count { matchCount = count }
            if activeMatch != active { activeMatch = active }
        }
    }
}

// MARK: - Binary File Preview
struct BinaryFilePreview: View {
    let url: URL
    @State private var dump = ""
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView("Cannot Read Binary File", systemImage: "doc.badge.exclamationmark", description: Text(error))
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(dump)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: url) { await load() }
    }

    private func load() async {
        let result = await Task.detached(priority: .utility) { () -> Result<String, Error> in
            Result {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let bytes = Array(data.prefix(256 * 1_024))
                var lines: [String] = []
                lines.reserveCapacity((bytes.count + 15) / 16)
                for offset in stride(from: 0, to: bytes.count, by: 16) {
                    let chunk = Array(bytes[offset..<min(offset + 16, bytes.count)])
                    let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
                    let padded = hex.padding(toLength: 47, withPad: " ", startingAt: 0)
                    let ascii = String(chunk.map { $0 >= 32 && $0 < 127 ? Character(UnicodeScalar($0)) : "." })
                    lines.append(String(format: "%08X  %@  |%@|", offset, padded, ascii))
                }
                if data.count > bytes.count { lines.append("\n— Preview truncated at 256 KB —") }
                return lines.joined(separator: "\n")
            }
        }.value
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let value): dump = value; error = nil
        case .failure(let failure): dump = ""; error = failure.localizedDescription
        }
    }
}
