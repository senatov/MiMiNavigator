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
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView("Cannot Read Text", systemImage: "doc.badge.exclamationmark", description: Text(error))
            } else {
                ReadOnlyTextView(text: text)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: url) { await load() }
    }

    private func load() async {
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

// MARK: - Read-Only Text View
private struct ReadOnlyTextView: NSViewRepresentable {
    let text: String

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
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
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
