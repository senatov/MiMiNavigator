// FeedbackCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 31.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinator and content view for the feedback choices panel.

import AppKit
import SwiftUI

// MARK: - Feedback Coordinator
@MainActor
final class FeedbackCoordinator: NSObject, NSWindowDelegate {
    static let shared = FeedbackCoordinator()
    private var panel: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.FeedbackWindow"

    // MARK: - Init
    private override init() {
        super.init()
    }

    // MARK: - Show
    func show() {
        WindowReplacement.close(panel)
        panel = nil
        let p = makePanel()
        WindowPresentationPolicy.presentStandalone(p)
        panel = p
        log.debug("[Feedback] panel shown")
    }

    // MARK: - Bring to Front
    func bringToFront() {
        guard let panel, panel.isVisible else { return }
        WindowPresentationPolicy.raiseStandalone(panel)
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        panel = nil
        log.debug("[Feedback] panel closed")
    }

    // MARK: - Close
    private func close() {
        panel?.close()
    }

    // MARK: - Build Panel
    private func makePanel() -> NSPanel {
        let view = FeedbackWindowContent(
            onOpenComments: { [weak self] in
                FeedbackReporter.openBlogComments()
                self?.close()
            },
            onSendDiagnostics: { [weak self] in
                FeedbackReporter.openReview(
                    title: "Diagnostics",
                    message: "Describe what happened before the error."
                )
                self?.close()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hostingView = NSHostingView(rootView: view)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "Feedback"
        p.contentView = hostingView
        p.delegate = self
        p.isMovableByWindowBackground = true
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.backgroundColor = .windowBackgroundColor
        p.becomesKeyOnlyIfNeeded = false
        WindowPresentationPolicy.apply(.standalone, to: p)
        AuxiliaryWindowFramePolicy.restoreOrCenter(
            p,
            autosaveName: frameAutosaveName,
            designedSize: NSSize(width: 470, height: 360)
        )
        return p
    }
}

// MARK: - Feedback Window Content
struct FeedbackWindowContent: View {
    let onOpenComments: () -> Void
    let onSendDiagnostics: () -> Void
    let onClose: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text("Review a short, privacy-filtered comment before MiMiNavigator fills the Blogger form.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                FeedbackActionButton(
                    title: "Open Blog Comments",
                    subtitle: "Review a short template, then fill Blogger.",
                    systemImage: "bubble.left.and.text.bubble.right",
                    action: onOpenComments
                )
                FeedbackActionButton(
                    title: "Report an Error",
                    subtitle: "Review error details, then open Blogger.",
                    systemImage: "ladybug.fill",
                    isProminent: true,
                    action: onSendDiagnostics
                )
            }
            HStack {
                Spacer()
                DownToolbarButtonView(title: "Close", systemImage: "xmark", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 470)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Text("💬")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text("MiMiNavigator Feedback")
                    .font(.system(size: 18, weight: .semibold))
                Text("Comments and diagnostics")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Feedback Action Button
private struct FeedbackActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isProminent = false
    let action: () -> Void

    // MARK: - Body
    var body: some View {
        Button(action: action) {
            HStack(spacing: isProminent ? 16 : 12) {
                Image(systemName: systemImage)
                    .font(.system(size: isProminent ? 28 : 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isProminent ? Color(#colorLiteral(red: 0.86, green: 0.30, blue: 0.18, alpha: 1.0)) : Color.accentColor)
                    .frame(width: isProminent ? 36 : 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: isProminent ? 17 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: isProminent ? 12 : 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, isProminent ? 10 : 6)
            .padding(.vertical, isProminent ? 10 : 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ThemedButtonStyle(tint: isProminent ? Color(#colorLiteral(red: 0.86, green: 0.30, blue: 0.18, alpha: 1.0)) : nil))
        .keyboardFocusable()
    }
}
