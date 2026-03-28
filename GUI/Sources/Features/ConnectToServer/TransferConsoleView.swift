// TransferConsoleView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI content of the remote transfer console window.
//   Shows real-time log stream, per-file progress, speed, ETA, cancel button.
//   Extracted from RemoteTransferConsole.swift for single responsibility.

import SwiftUI


// MARK: - TransferConsoleView

struct TransferConsoleView: View {

    let progress: RemoteTransferProgress
    @State private var autoScroll = true

    // MARK: - Design tokens
    private enum D {
        static let consoleBg   = Color(nsColor: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1))
        static let consoleText = Color(nsColor: NSColor(calibratedRed: 0.78, green: 0.93, blue: 0.78, alpha: 1))
        static let dimText     = Color(nsColor: NSColor(calibratedRed: 0.5,  green: 0.6,  blue: 0.5,  alpha: 1))
        static let accentGreen = Color(nsColor: NSColor(calibratedRed: 0.2,  green: 0.85, blue: 0.4,  alpha: 1))
        static let accentRed   = Color(nsColor: NSColor(calibratedRed: 1.0,  green: 0.35, blue: 0.35, alpha: 1))
        static let monoFont    = Font.system(size: 11, weight: .regular, design: .monospaced)
        static let labelFont   = Font.system(size: 11, weight: .medium)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            consoleLog
            Divider()
            footerBar
        }
        .background(D.consoleBg)
    }



    // MARK: - headerBar

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: progress.direction.icon)
                .foregroundStyle(D.accentGreen)
                .font(.system(size: 16, weight: .light))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(progress.direction.title) · \(progress.serverLabel)")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.primary)
                Text(progress.statusLine)
                    .font(D.labelFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if !progress.speedText.isEmpty {
                    Text(progress.speedText)
                        .font(D.labelFont)
                        .foregroundStyle(D.accentGreen)
                        .monospacedDigit()
                }
                if !progress.etaText.isEmpty {
                    Text(progress.etaText)
                        .font(D.labelFont)
                        .foregroundStyle(D.dimText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }



    // MARK: - consoleLog

    private var consoleLog: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(progress.logLines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(D.monoFont)
                            .foregroundStyle(lineColor(line))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 1)
                            .id(idx)
                    }
                }
                .padding(.vertical, 6)
            }
            .background(D.consoleBg)
            .onChange(of: progress.logLines.count) { _, count in
                if autoScroll, count > 0 {
                    withAnimation(.none) { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
        }
    }



    // MARK: - footerBar

    private var footerBar: some View {
        HStack(spacing: 12) {
            progressBar
            Spacer()
            Text(bytesLabel)
                .font(D.labelFont)
                .foregroundStyle(D.dimText)
                .monospacedDigit()
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .font(D.labelFont)
                .foregroundStyle(D.dimText)
            actionButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }



    // MARK: - progressBar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(4, geo.size.width * progress.fraction))
                    .animation(.linear(duration: 0.2), value: progress.fraction)
            }
        }
        .frame(height: 6)
        .frame(minWidth: 120, maxWidth: 240)
    }



    // MARK: - actionButton

    private var actionButton: some View {
        Group {
            if progress.isCompleted || progress.isCancelled {
                Button("Close") { RemoteTransferConsole.shared.close() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.secondary)
            } else {
                Button("Cancel") { progress.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(D.accentRed)
            }
        }
    }



    // MARK: - Helpers

    private func lineColor(_ line: String) -> Color {
        if line.contains("✓") { return D.accentGreen }
        if line.contains("✗") { return D.accentRed }
        if line.contains("—") { return D.dimText }
        return D.consoleText
    }

    private var barColor: Color {
        if progress.isCancelled { return D.accentRed }
        if progress.isCompleted { return D.accentGreen }
        return Color.accentColor
    }

    private var bytesLabel: String {
        let done  = ByteCountFormatter.string(fromByteCount: progress.transferredBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: progress.totalBytes,       countStyle: .file)
        return progress.totalBytes > 0 ? "\(done) / \(total)" : "\(progress.doneCount)/\(progress.totalFiles) files"
    }
}
