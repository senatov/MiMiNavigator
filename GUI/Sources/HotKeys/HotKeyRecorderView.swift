// HotKeyRecorderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Inline key recorder — captures next keypress as new shortcut binding

import AppKit
import SwiftUI

// MARK: - Hot Key Recorder
/// A button that, when clicked, captures the next keypress to assign as a shortcut.
/// Shows the current binding or "Press a key…" while recording.
struct HotKeyRecorderView: View {
    let binding: HotKeyBinding
    let onRecord: (UInt16, HotKeyModifiers) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: { startRecording() }) {
            HStack(spacing: 4) {
                if isRecording {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Press a key…")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else {
                    Text(binding.displayString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .frame(minWidth: 100, alignment: .center)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording
                          ? Color.orange.opacity(0.12)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.orange.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else {
            stopRecording()
            return
        }
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            let keyCode = event.keyCode
            let mods = HotKeyModifiers.fromNSFlags(event.modifierFlags)

            // Escape alone cancels recording
            if keyCode == 0x35 && mods.subtracting(.function).isEmpty {
                stopRecording()
                return nil
            }

            onRecord(keyCode, mods)
            stopRecording()
            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
