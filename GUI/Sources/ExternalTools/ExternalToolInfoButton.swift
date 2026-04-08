// ExternalToolInfoButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: (i) info button — shows install instructions popover for missing tools.
//   If brew is missing, first suggests installing brew itself.
//   Copies install command to clipboard on click. Shows website link if available.

import AppKit
import SwiftUI


// MARK: - ExternalToolInfoButton

struct ExternalToolInfoButton: View {

    let tool: ExternalTool
    @State private var showPopover = false


    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Install \(tool.name)")
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            toolInfoPopoverContent
        }
    }


    // MARK: - Popover content

    @ViewBuilder
    private var toolInfoPopoverContent: some View {
        let registry = ExternalToolRegistry.shared
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(tool.purpose)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            // Brew section
            if let formula = tool.brewFormula {
                if registry.brewAvailable {
                    brewCommandRow(formula: formula)
                } else {
                    brewNotInstalledSection(formula: formula)
                }
            }
            // Website link
            if let urlStr = tool.websiteURL, let url = URL(string: urlStr) {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                    Link(urlStr, destination: url)
                        .font(.system(size: 11))
                }
            }
            // Refresh button
            HStack {
                Spacer()
                Button {
                    registry.refreshSingle(tool.id)
                    if registry.isAvailable(tool.id) {
                        showPopover = false
                    }
                } label: {
                    Label("Re-check", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 320)
    }


    // MARK: - Brew command (brew available)

    private func brewCommandRow(formula: String) -> some View {
        let cmd = "brew install \(formula)"
        return VStack(alignment: .leading, spacing: 6) {
            Text("Install via Homebrew:")
                .font(.system(size: 12, weight: .medium))
            HStack(spacing: 6) {
                Text(cmd)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    log.info("[ToolInfo] copied '\(cmd)' to clipboard")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Copy to clipboard")
            }
            Text("Paste this command into Terminal.app and press Enter.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Brew not installed

    private func brewNotInstalledSection(formula: String) -> some View {
        let brewInstallCmd = """
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                Text("Homebrew is not installed")
                    .font(.system(size: 12, weight: .medium))
            }
            Text("Homebrew is needed to install \(tool.name). Install it first:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 1 — Install Homebrew (requires admin password):")
                    .font(.system(size: 11, weight: .medium))
                HStack(spacing: 6) {
                    Text(brewInstallCmd)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(brewInstallCmd, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Copy to clipboard")
                }
                Text("Step 2 — Then install \(tool.name):")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    let cmd = "brew install \(formula)"
                    Text(cmd)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .help("Copy to clipboard")
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "safari")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Link("https://brew.sh", destination: URL(string: "https://brew.sh")!)
                    .font(.system(size: 11))
            }
        }
    }
}
