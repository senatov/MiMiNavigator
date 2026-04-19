//
//  MediaInfoPanel+Create.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import AVKit
import SwiftUI

@MainActor
extension MediaInfoPanel {
    func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: LayoutConstants.panelSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.level = .normal
        panel.titlebarAppearsTransparent = false
        panel.toolbarStyle = .unified
        panel.animationBehavior = .default
        panel.tabbingMode = .disallowed
        panel.standardWindowButton(.closeButton)?.keyEquivalent = "\u{1b}"
        panel.minSize = LayoutConstants.minPanelSize
        PanelTitleHelper.applyIconTitle(
            to: panel,
            systemImage: "info.circle",
            title: "Media & Convert"
        )

        panel.contentView = NSHostingView(rootView: MediaInfoPanelView(controller: self))
        panel.center()
        self.panel = panel
    }
}

private struct MediaInfoPanelView: View {
    @ObservedObject var controller: MediaInfoPanel
    private var colorTheme: ColorTheme { ColorThemeStore.shared.activeTheme }

    private enum Layout {
        static let minWidth: CGFloat = 720
        static let idealWidth: CGFloat = 920
        static let minHeight: CGFloat = 460
        static let outerCornerRadius: CGFloat = 14
        static let sectionCornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let compactHorizontalPadding: CGFloat = 10
        static let infoLabelWidth: CGFloat = 96
        static let leftColumnMinWidth: CGFloat = 420
        static let previewMinWidth: CGFloat = 280
        static let previewIdealWidth: CGFloat = 420
        static let sectionButtonTopPadding: CGFloat = 6
        static let bottomButtonSpacing: CGFloat = 12
    }

    private struct InfoSection: Identifiable {
        let id = UUID()
        let title: String
        let rows: [InfoRow]
    }

    private struct InfoRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    private var darkNavyValueColor: Color {
        Color(nsColor: NSColor(red: 0.10, green: 0.15, blue: 0.55, alpha: 1.0))
    }

    private var sectionHeaderColor: Color {
        Color.primary.opacity(0.92)
    }

    private var parsedSections: [InfoSection] {
        var sections: [InfoSection] = []
        var currentTitle = "File"
        var currentRows: [InfoRow] = []

        func flush() {
            guard !currentRows.isEmpty else { return }
            sections.append(InfoSection(title: currentTitle, rows: currentRows))
            currentRows = []
        }

        for rawLine in controller.rawText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("---") {
                flush()
                currentTitle = line.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
                continue
            }
            if let separator = line.firstIndex(of: ":") {
                let label = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                currentRows.append(InfoRow(label: label, value: value))
            } else {
                currentRows.append(InfoRow(label: "", value: line))
            }
        }

        flush()
        return sections
    }

    var body: some View {
        VStack(spacing: 10) {
            headerBar
            contentBody
            buttonBar
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.idealWidth, minHeight: Layout.minHeight)
        .padding(.top, 10)
        .background(panelBackground)
        .glassEffect(.regular)
        .overlay(panelBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous))
        .onKeyPress(.escape) {
            controller.hide()
            return .handled
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Media")
                    Image(systemName: "info.circle")
                    Text("& Convert")
                }
                .font(.headline)

                Text(controller.currentURL?.lastPathComponent ?? controller.displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 6) {
                navButton(symbol: "chevron.left", action: controller.prevMedia, disabled: controller.currentIndex <= 0)
                navButton(symbol: "chevron.right", action: controller.nextMedia, disabled: controller.currentIndex >= controller.mediaFiles.count - 1)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 8)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.compactHorizontalPadding)
    }

    private func navButton(symbol: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption)
                .padding(6)
                .background {
                    Circle().fill(.quaternary.opacity(0.9))
                }
                .overlay {
                    Circle().strokeBorder(.quaternary, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var contentBody: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                convertCard
                    .fixedSize(horizontal: false, vertical: true)
                infoCard
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(minWidth: Layout.leftColumnMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, Layout.compactHorizontalPadding)
            .padding(.bottom, 10)

            previewCard
                .frame(maxHeight: .infinity)
                .padding(.trailing, Layout.compactHorizontalPadding)
                .padding(.bottom, 10)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("File")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(sectionHeaderColor)
                .textCase(.uppercase)

            ViewThatFits(in: .vertical) {
                fileContent
                ScrollView {
                    fileContent
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 12)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parsedSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    if section.title.caseInsensitiveCompare("File") != .orderedSame {
                        Text(section.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(sectionHeaderColor)
                            .textCase(.uppercase)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(section.rows) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if row.label.isEmpty {
                                    Text(row.value)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.primary)
                                } else {
                                    Text(row.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: Layout.infoLabelWidth, alignment: .leading)
                                    Text(row.value)
                                        .font(.system(size: 13))
                                        .foregroundStyle(valueColor(for: row.label))
                                        .textSelection(.enabled)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }

            if let coordinates = controller.currentCoordinates {
                mapsCard(coordinates: coordinates)
            }
        }
    }

    private func mapsCard(coordinates: (Double, Double)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Maps")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(sectionHeaderColor)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                mapLink("Apple", "https://maps.apple.com/?ll=\(coordinates.0),\(coordinates.1)")
                mapLink("Google", "https://www.google.com/maps?q=\(coordinates.0),\(coordinates.1)")
                mapLink("OSM", "https://www.openstreetmap.org/?mlat=\(coordinates.0)&mlon=\(coordinates.1)#map=15/\(coordinates.0)/\(coordinates.1)")
            }
        }
    }

    private func mapLink(_ title: String, _ urlString: String) -> some View {
        Link(title, destination: URL(string: urlString)!)
            .font(.system(size: 12, weight: .medium))
    }

    private func valueColor(for label: String) -> Color {
        switch label {
        case "Path":
            return darkNavyValueColor
        case "Size":
            return colorTheme.columnSizeColor
        case "Created", "Modified":
            return colorTheme.columnDateColor
        default:
            return .primary
        }
    }

    private var convertCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Convert")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(sectionHeaderColor)
                .textCase(.uppercase)

            if controller.isConvertible {
                row("Format") {
                    Picker("", selection: $controller.targetFormat) {
                        ForEach(controller.availableFormats) { format in
                            Label(format.displayName, systemImage: format.systemImage).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280, alignment: .leading)
                }

                row("Output") {
                    TextField("Filename", text: $controller.outputName)
                        .textFieldStyle(.roundedBorder)
                    Text(".\(controller.targetFormat.fileExtension)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                row("Folder") {
                    Text(controller.outputDir)
                        .font(.system(size: 13))
                        .foregroundStyle(darkNavyValueColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    DownToolbarButtonView(
                        title: "Choose…",
                        systemImage: "folder",
                        action: controller.chooseOutputDir
                    )
                }

                row("Backend") {
                    Text(controller.toolInfo)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Toggle("Delete original", isOn: $controller.deleteOriginal)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))

                HStack {
                    Spacer()
                    DownToolbarButtonView(
                        title: "Convert",
                        systemImage: "arrow.triangle.2.circlepath",
                        action: controller.performConvert
                    )
                    .disabled(!controller.isValidConversion)
                }
                .padding(.top, Layout.sectionButtonTopPadding)
            } else {
                Text("Conversion is not available for this file type.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 12)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Layout.infoLabelWidth, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private var previewCard: some View {
        Group {
            switch controller.previewMode {
            case .image:
                if let image = controller.previewImage {
                    if controller.isAnimatedImagePreview {
                        MediaInfoAnimatedImagePreview(image: image)
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    previewPlaceholder
                }
            case .video:
                MediaInfoVideoPreview(controller: controller)
            case .none:
                previewPlaceholder
            }
        }
        .frame(minWidth: Layout.previewMinWidth, idealWidth: Layout.previewIdealWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(sectionBackground)
        .overlay(sectionBorder)
        .clipShape(RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous))
    }

    private var previewPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Preview unavailable")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var buttonBar: some View {
        HStack(spacing: Layout.bottomButtonSpacing) {
            DownToolbarButtonView(
                title: "Copy Path",
                systemImage: "link",
                action: controller.copyPathAction
            )

            DownToolbarButtonView(
                title: "Copy All",
                systemImage: "doc.on.doc",
                action: controller.copyAllAction
            )

            Spacer()

            DownToolbarButtonView(
                title: "Reveal",
                systemImage: "folder",
                action: controller.revealAction
            )

            DownToolbarButtonView(
                title: "Close",
                systemImage: "xmark.circle",
                action: controller.closeAction
            )
        }
        .padding(.horizontal, Layout.compactHorizontalPadding)
        .padding(.bottom, 10)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .fill(.clear)
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: Layout.outerCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .fill(.clear)
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: Layout.sectionCornerRadius, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 0.8)
    }
}

private struct MediaInfoVideoPreview: NSViewRepresentable {
    @ObservedObject var controller: MediaInfoPanel

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .default
        view.showsFrameSteppingButtons = true
        view.updatesNowPlayingInfoCenter = false
        controller.playerView = view
        controller.showCurrentVideoPreviewIfPossible()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        controller.playerView = nsView
        controller.showCurrentVideoPreviewIfPossible()
    }
}

private struct MediaInfoAnimatedImagePreview: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.animates = true
        view.image = image
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.animates = true
        nsView.image = image
    }
}
