// DiagnosticReportPresenter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shows the complete sanitized report before the user may copy it to Blogger.

import AppKit
import SwiftUI

// MARK: - Diagnostic Report Presenter
@MainActor
final class DiagnosticReportPresenter: NSObject, NSWindowDelegate {
    static let shared = DiagnosticReportPresenter()
    private var panel: NSPanel?
    private override init() {}

    // MARK: - Show
    func show(_ report: String) {
        WindowReplacement.close(panel)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: DiagnosticReportReviewView(report: report, onCancel: { [weak self] in self?.close() }, onSubmit: { [weak self] reviewedText in
            FeedbackReporter.copyAndOpenBlog(reviewedText)
            self?.close()
        }))
        panel.title = "Review Diagnostic Report"
        panel.minSize = NSSize(width: 560, height: 420)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        WindowPresentationPolicy.apply(.standalone, to: panel)
        panel.center()
        WindowPresentationPolicy.presentStandalone(panel)
        self.panel = panel
    }

    // MARK: - Close
    private func close() {
        panel?.close()
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        panel?.contentView = nil
        panel = nil
    }
}

// MARK: - Diagnostic Report Review View
private struct DiagnosticReportReviewView: View {
    @State private var report: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    init(report: String, onCancel: @escaping () -> Void, onSubmit: @escaping (String) -> Void) {
        _report = State(initialValue: report)
        self.onCancel = onCancel
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review before publishing")
                .font(.title3.weight(.semibold))
            Text("Nothing is sent automatically. Personal identifiers and common secrets were removed, but check the complete text and edit or delete anything you do not want to publish.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $report)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary) }
            Text("The next button only copies this text and opens Blogger. You decide whether to publish the comment and which Blogger identity to use.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                DownToolbarButtonView(title: "Cancel", systemImage: "xmark", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                DownToolbarButtonView(title: "Copy & Open Blog", systemImage: "doc.on.clipboard", action: { onSubmit(report) })
                    .keyboardShortcut(.defaultAction)
                    .disabled(report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }
}
