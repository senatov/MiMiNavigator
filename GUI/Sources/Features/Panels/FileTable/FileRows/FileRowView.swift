    // FileRowView.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 11.08.2024.
    // Copyright © 2024-2026 Senatov. All rights reserved.
    // Description: File row content view — icon + name.
    //              Icon logic extracted to SmartIconService.swift.
    //              Async icon loading via AsyncSmartIconView (nested).

    import AppKit
    import FileModelKit
    import SwiftUI
    import UniformTypeIdentifiers

    // MARK: - File row content view (icon + name)
    struct FileRowView: View {
        let file: CustomFile
        let isSelected: Bool
        let isActivePanel: Bool
        var isMarked: Bool = false
        private let colorStore = ColorThemeStore.shared

        // MARK: - View Body
        var body: some View {
            baseContent()
                .padding(.vertical, DesignTokens.grid / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }

        // MARK: - Parent entry check
        private var isParentEntry: Bool {
            ParentDirectoryEntry.isParentEntry(file)
        }

        // MARK: - Name color
        private var nameColor: Color {
            if isMarked { return colorStore.activeTheme.markedFileColor }
            if isParentEntry { return colorStore.activeTheme.parentEntryColor }
            if file.isHidden { return colorStore.activeTheme.hiddenFileColor }
            if file.isSymbolicLink { return colorStore.activeTheme.symlinkColor }
            if file.isDirectory { return colorStore.activeTheme.dirNameColor }
            return colorStore.activeTheme.fileNameColor
        }

        // MARK: - Constants
        private static let nameWeight: Font.Weight = .regular
        private static let nameFontSize: CGFloat = 13

        // MARK: - Icon opacity (dimming for hidden files)
        private var iconOpacity: Double {
            file.isHidden ? 0.45 : 1.0
        }

        // MARK: - Base content
        private func baseContent() -> some View {
            if isParentEntry {
                return AnyView(parentEntryRow)
            }
            return AnyView(normalFileRow)
        }

        // MARK: - Parent entry row ("..")
        private var parentEntryRow: some View {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.Row.iconSize + 2, height: DesignTokens.Row.iconSize + 2)
                    .foregroundStyle(colorStore.activeTheme.parentEntryColor)
                Text("...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        // MARK: - Normal file row
        private var normalFileRow: some View {
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncSmartIconView(file: file)
                        .frame(width: DesignTokens.Row.iconSize, height: DesignTokens.Row.iconSize)
                        .opacity(iconOpacity)
                        .allowsHitTesting(false)

                    switch file.securityState {
                    case .restricted:
                        Image(systemName: "lock.square.stack")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(#colorLiteral(red: 0.3098039329, green: 0.01568627544, blue: 0.1294117719, alpha: 1)))
                            .offset(x: 2, y: 2)
                    case .systemProtected:
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(#colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)))
                            .offset(x: 2, y: 2)
                    case .immutable:
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(#colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)))
                            .offset(x: 2, y: 2)
                    case .brokenSymlink:
                        Image(systemName: "exclamationmark.link")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))
                            .offset(x: 2, y: 2)
                    case .specialDevice:
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1)))
                            .offset(x: 2, y: 2)
                    case .normal:
                        EmptyView()
                    }
                }
                .layoutPriority(1)
                HStack(spacing: 4) {
                    if isMarked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(colorStore.activeTheme.markedFileColor)
                    }
                    Text(file.nameStr)
                        .font(.system(size: Self.nameFontSize, weight: Self.nameWeight))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .overlay(alignment: .trailing) {
                    FileInfoButton(file: file, isSelected: isSelected)
                }
                .layoutPriority(0)
            }
        }

        // MARK: - Async icon loader
        struct AsyncSmartIconView: View {
            let file: CustomFile
            @State private var icon: NSImage?

            var body: some View {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "doc")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .task(id: file.urlValue.path) {
                    let result =
                        await Task.detached(priority: .utility) {
                            await SmartIconService.icon(for: file)
                        }
                        .value
                    await MainActor.run { self.icon = result }
                }
            }
        }
    }

    // MARK: - Backward compatibility bridge
    extension FileRowView {
        /// Legacy API — redirects to SmartIconService
        @MainActor
        static func getSmartIcon(for file: CustomFile) -> NSImage {
            SmartIconService.icon(for: file)
        }

        /// Legacy API — redirects to SmartIconService
        @MainActor
        static func getSmartIcon(for url: URL, size: NSSize = NSSize(width: 128, height: 128)) -> NSImage {
            SmartIconService.icon(for: url, size: size)
        }
    }
