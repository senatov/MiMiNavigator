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
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let p = makePanel()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p
        log.debug("[Feedback] panel shown")
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
                FeedbackReporter.sendDiagnosticsEmail()
                self?.close()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hostingView = NSHostingView(rootView: view)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 260),
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
        p.isFloatingPanel = false
        p.becomesKeyOnlyIfNeeded = false
        p.level = .normal
        p.hidesOnDeactivate = false
        p.tabbingMode = .disallowed
        if !p.setFrameUsingName(frameAutosaveName) {
            p.center()
        }
        p.setFrameAutosaveName(frameAutosaveName)
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
        VStack(alignment: .leading, spacing: 18) {
            header
            Text("Open the public feedback post for short comments, or send a diagnostics package by email if logs are needed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                FeedbackActionButton(
                    title: "Open Blog Comments",
                    subtitle: "Copies a short template and opens Blogger comments.",
                    systemImage: "bubble.left.and.text.bubble.right",
                    action: onOpenComments
                )
                FeedbackActionButton(
                    title: "Send Diagnostics by Email",
                    subtitle: "Creates a ZIP with app version, macOS version, and MiMiNavigator logs.",
                    systemImage: "envelope.badge",
                    action: onSendDiagnostics
                )
            }
            HStack {
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 430)
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
    let action: () -> Void

    // MARK: - Body
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
