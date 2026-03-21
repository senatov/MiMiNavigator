// AboutView.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: About window — app info, version, credits, third-party libraries.

import SwiftUI

// MARK: - AboutView
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appName = "MiMiNavigator"
    private let tagline = "Dual-panel file manager for macOS"
    private let copyright = "© 2024–2026 Iakov Senatov"
    private let githubURL = "https://github.com/senatov/MiMiNavigator"
    
    private var version: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }
    
    private var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 20)
                infoSection
                Divider().padding(.horizontal, 20)
                linksSection
                Divider().padding(.horizontal, 20)
                acknowledgmentsSection
                Divider().padding(.horizontal, 20)
                creditsSection
            }
        }
        .frame(width: 460, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            closeButton
                .background(.bar)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            
            Text(appName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(tagline)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 6) {
            infoRow(label: "Version", value: version)
            infoRow(label: "System", value: macOSVersion)
            infoRow(label: "Architecture", value: architectureString)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 12))
    }
    
    private var architectureString: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - Links Section
    private var linksSection: some View {
        VStack(spacing: 10) {
            linkButton(
                title: "MiMiNavigator on GitHub",
                subtitle: "Source code, releases, documentation",
                icon: "link",
                url: githubURL
            )
            linkButton(
                title: "Report Issue",
                subtitle: "Found a bug? Let us know",
                icon: "ladybug",
                url: "\(githubURL)/issues/new"
            )
            linkButton(
                title: "View License",
                subtitle: "MIT License",
                icon: "doc.text",
                url: "\(githubURL)/blob/main/LICENSE"
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }
    
    private func linkButton(title: String, subtitle: String, icon: String, url: String) -> some View {
        Button {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acknowledgments (Third-Party Libraries)
    private var acknowledgmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Third-Party Libraries")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 6) {
                libraryRow(
                    name: "SwiftyBeaver",
                    description: "Colorful logging framework",
                    url: "https://github.com/SwiftyBeaver/SwiftyBeaver",
                    license: "MIT"
                )
                libraryRow(
                    name: "FileProvider",
                    description: "Cloud & network file access",
                    url: "https://github.com/amosavian/FileProvider",
                    license: "MIT"
                )
                libraryRow(
                    name: "Citadel",
                    description: "SSH/SFTP client library",
                    url: "https://github.com/orlandos-nl/Citadel",
                    license: "MIT"
                )
                libraryRow(
                    name: "Swift System",
                    description: "Low-level system interfaces",
                    url: "https://github.com/apple/swift-system",
                    license: "Apache 2.0"
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }
    
    private func libraryRow(name: String, description: String, url: String, license: String) -> some View {
        Button {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(license)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Credits Section
    private var creditsSection: some View {
        VStack(spacing: 8) {
            Text("Built with")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 12) {
                creditBadge("Swift 6", color: .orange)
                creditBadge("SwiftUI", color: .blue)
                creditBadge("AppKit", color: .purple)
            }
            
            Text(copyright)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            
            Text("Released under MIT License")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
    }
    
    private func creditBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
    
    // MARK: - Close Button
    private var closeButton: some View {
        HStack {
            Spacer()
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Preview
#Preview {
    AboutView()
}
