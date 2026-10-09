// AboutView.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: About window — app info, version, credits, third-party libraries.

import SwiftUI

// MARK: - AboutView
struct AboutView: View {
    var onClose: (() -> Void)?

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
                architectureSection
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
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 6) {
            infoRow(label: "Version", value: version)
            infoRow(label: "System", value: macOSVersion)
            infoRow(label: "Architecture", value: "Apple Silicon (arm64)")
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
        .font(.callout)
    }

    // MARK: - Links Section
    private var linksSection: some View {
        VStack(spacing: 10) {
            AboutActionRow(
                title: "MiMiNavigator on GitHub",
                subtitle: "Source code, releases, documentation",
                systemImage: "link",
                iconTint: .blue,
                url: githubURL
            )
            AboutActionRow(
                title: "Report Issue",
                subtitle: "Found a bug? Let us know",
                systemImage: "ladybug",
                iconTint: .red,
                url: "\(githubURL)/issues/new"
            )
            AboutActionRow(
                title: "View License",
                subtitle: "GNU Affero General Public License v3.0",
                systemImage: "doc.text",
                iconTint: .blue,
                url: "\(githubURL)/blob/master/LICENSE"
            )
            AboutActionRow(
                title: "Third-Party Notices",
                subtitle: "Libraries, external tools, versions, and licenses",
                systemImage: "shippingbox",
                iconTint: .blue,
                url: "\(githubURL)/blob/master/THIRD_PARTY_NOTICES.md"
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }

    // MARK: - Application Architecture
    private var architectureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Application Architecture")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                architectureRow(
                    name: "CacheKit",
                    description: "SQLite-backed persistent cache with TTL and LRU pruning",
                    icon: "externaldrive.badge.timemachine"
                )
                architectureRow(
                    name: "Two-level caching",
                    description: "Bounded in-memory L1 with persistent, validated L2 storage",
                    icon: "square.2.layers.3d"
                )
                architectureRow(
                    name: "NetworkKit",
                    description: "Network discovery, neighborhood browsing, and remote mounts",
                    icon: "network"
                )
                architectureRow(
                    name: "FavoritesKit",
                    description: "Sandbox-aware favorites, bookmarks, and sidebar presentation",
                    icon: "star"
                )
                architectureRow(
                    name: "FileModelKit & ScannerKit",
                    description: "File metadata model and asynchronous directory scanning",
                    icon: "doc.text.magnifyingglass"
                )
                architectureRow(
                    name: "ArchiveKit & RenameKit",
                    description: "Archive virtual filesystem and batch rename operations",
                    icon: "archivebox"
                )
                architectureRow(
                    name: "LogKit",
                    description: "Shared structured diagnostics across application modules",
                    icon: "text.alignleft"
                )
                architectureRow(
                    name: "FindFilesKit",
                    description: "Streaming file, content, Spotlight, and archive search engine",
                    icon: "magnifyingglass"
                )
                architectureRow(
                    name: "MediaMetadataKit",
                    description: "Image, audio, video, EXIF, and GPS metadata extraction",
                    icon: "info.circle"
                )
                architectureRow(
                    name: "ExternalToolsKit",
                    description: "External command-line tool discovery and health state",
                    icon: "wrench.and.screwdriver"
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }

    private func architectureRow(name: String, description: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Acknowledgments (Third-Party Libraries)
    private var acknowledgmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Third-Party Libraries")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(AboutDependencyCatalog.libraries) { dependency in
                    AboutActionRow(title: dependency.name, subtitle: "\(dependency.description) · \(dependency.license)", systemImage: "shippingbox", iconTint: .blue, url: dependency.url)
                }
                Text("Optional External Tools")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                ForEach(AboutDependencyCatalog.externalTools) { dependency in
                    AboutActionRow(title: dependency.name, subtitle: "\(dependency.description) · \(dependency.license)", systemImage: "wrench.and.screwdriver", iconTint: .purple, url: dependency.url)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }

    // MARK: - Credits Section
    private var creditsSection: some View {
        VStack(spacing: 8) {
            Text("Built with")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                creditBadge("Swift 6.2", color: .blue)
                creditBadge("SwiftUI", color: .blue)
                creditBadge("AppKit", color: .purple)
            }

            Text(copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Text("Released under GNU AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }

    private func creditBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Close Button
    private var closeButton: some View {
        HStack {
            Spacer()
            DownToolbarButtonView(title: "Close", systemImage: "xmark", iconTint: .red) {
                onClose?()
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
