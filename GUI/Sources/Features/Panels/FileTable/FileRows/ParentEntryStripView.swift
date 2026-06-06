// ParentEntryStripView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ".." parent-navigation strip with corner-triangle pebble button.
//   ◤ /ParentDir (N dirs)  — N respects Show Hidden setting.

import FileModelKit
import AppKit
import SwiftUI

// MARK: - ParentEntryStripView
struct ParentEntryStripView: View {
    static let rowHeight: CGFloat = 25

    let file: CustomFile
    let isSelected: Bool
    let parentURL: URL
    let onSelect: (CustomFile) -> Void
    let onActivate: (CustomFile) -> Void
    private var label: String { "\(parentName)   (\(rowsCount) dirs)" }
    private var textColor: Color {
        pebbleActive
            ? Color(#colorLiteral(red: 1, green: 0.92, blue: 0.05, alpha: 1))
            : Color.black
    }
    private let borderColor = Color(#colorLiteral(red: 0.55, green: 0.55, blue: 0.58, alpha: 1))
    private var pebbleActive: Bool { isSelected || isHovering }
    private var showHidden: Bool { UserPreferences.shared.snapshot.showHiddenFiles }
    private static let navigateUpCursor: NSCursor = {
        guard let image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Navigate up") else {
            return .pointingHand
        }
        image.size = NSSize(width: 18, height: 18)
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()

    private var parentName: String {
        parentURL.path == "/" ? "/Root" : parentURL.path
    }

    private var countTaskID: String {
        "\(parentURL.path)-\(showHidden)"
    }

    @State private var rowsCount: Int = 0
    @State private var isHovering = false

    private enum UI {
        static let stripHeight: CGFloat = 25
        static let buttonInset: CGFloat = 1
        static let buttonHeight: CGFloat = 24
        static let borderHeight: CGFloat = 1.5
        static let shadowRadius: CGFloat = 3.0
        static let shadowY: CGFloat = -2.0
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            stripContent(geo: geo)
        }
        .frame(maxWidth: .infinity)
        .frame(height: UI.stripHeight)
        .contentShape(Rectangle())
        .zIndex(10)
        .onHover { handleHoverChange($0) }
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    activateParentNavigation()
                }
        )
        .task(id: countTaskID) {
            await loadParentCount()
        }
    }

    // MARK: - Strip Content
    private func stripContent(geo: GeometryProxy) -> some View {
        ZStack(alignment: .leading) {
            Color.white
            fullWidthButton(geo: geo)
            bottomBorder
        }
    }

    private func handleHoverChange(_ isHoveringNow: Bool) {
        withAnimation(.easeInOut(duration: 0.10)) {
            isHovering = isHoveringNow
        }
    }

    // MARK: - Full Width Button
    private func fullWidthButton(geo: GeometryProxy) -> some View {
        return VStack(spacing: 0) {
            Button(action: activateParentNavigation) {
                HStack(spacing: 6) {
                    Image(systemName: pebbleActive ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(#colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1)))
                        .rotationEffect(
                            .degrees(pebbleActive ? -8 : 0),
                            anchor: .center
                        )
                        .animation(
                            pebbleActive
                                ? .interpolatingSpring(stiffness: 180, damping: 6)
                                : .easeOut(duration: 0.15),
                            value: pebbleActive
                        )
                    Text(label)
                        .font(.system(size: 10, weight: .thin, design: .monospaced))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(ParentStripButtonStyle(isHighlighted: pebbleActive))
            .frame(width: max(0, geo.size.width - UI.buttonInset * 2), height: UI.buttonHeight)
            .overlay(ParentStripCursorView(cursor: Self.navigateUpCursor))
            .padding(.horizontal, UI.buttonInset)
            Spacer()
        }
    }

    // MARK: - Bottom Border (prominent, with upward shadow)
    private var bottomBorder: some View {
        VStack {
            Spacer()
            borderColor
                .frame(height: UI.borderHeight)
                .shadow(color: .black.opacity(0.30), radius: UI.shadowRadius, x: 0, y: UI.shadowY)
        }
    }

    // MARK: - Parent Navigation
    private func activateParentNavigation() {
        log.debug("[ParentEntryStripView] activate parent path=\(parentURL.path)")
        onSelect(file)

        Task { @MainActor in
            log.debug("[ParentEntryStripView] navigate parent path=\(parentURL.path)")
            onActivate(file)
        }
    }

    // MARK: - Load Parent Directory Count
    private func loadParentCount() async {
        let url = parentURL
        let hidden = showHidden
        let count =
            await Task.detached(priority: .utility) {
                Self.countSubdirectories(in: url, showHidden: hidden)
            }
            .value
        await updateRowsCount(count)
    }

    private func updateRowsCount(_ count: Int) async {
        let newCount = count
        DispatchQueue.main.async {
            guard rowsCount != newCount else { return }
            rowsCount = newCount
        }
    }

    // MARK: - Count Subdirectories (off MainActor)
    nonisolated static func countSubdirectories(in url: URL, showHidden: Bool) -> Int {
        let fm = FileManager.default
        guard
            let items = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: []
            )
        else { return 0 }
        return
            items.filter { item in
                guard let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey]) else { return false }
                let isDir = vals.isDirectory ?? false
                let isHid = vals.isHidden ?? false
                return isDir && (showHidden || !isHid)
            }
            .count
    }
}

// MARK: - Parent Strip Button Style
private struct ParentStripButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    private let buttonShape = ParentStripButtonShape(topRadius: 3, bottomRadius: 11)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(buttonBackground)
            .background(.ultraThinMaterial)
            .overlay(buttonHighlight)
            .clipShape(buttonShape)
            .overlay(
                buttonShape
                    .stroke(Color.white.opacity(isHighlighted ? 0.75 : 0.45), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(isHighlighted ? 0.30 : 0.20), radius: 2, x: 0.8, y: 1.5)
            .shadow(color: .white.opacity(0.45), radius: 1, x: -0.4, y: -0.6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.16), value: isHighlighted)
            .animation(.bouncy, value: configuration.isPressed)
    }
    private var buttonBackground: some ShapeStyle {
        LinearGradient(
            colors: isHighlighted
                ? [
                    Color(#colorLiteral(red: 1, green: 0.86, blue: 0.90, alpha: 1)),
                    Color(#colorLiteral(red: 0.78, green: 0.70, blue: 0.96, alpha: 1)),
                    Color(#colorLiteral(red: 0.66, green: 0.60, blue: 0.88, alpha: 1))
                ]
                : [
                    Color(#colorLiteral(red: 0.86, green: 0.86, blue: 0.86, alpha: 0.92)),
                    Color(#colorLiteral(red: 0.72, green: 0.72, blue: 0.72, alpha: 0.86))
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    private var buttonHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(isHighlighted ? 0.48 : 0.60),
                Color.clear,
                Color.black.opacity(0.13)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.overlay)
    }
}

// MARK: - Parent Strip Button Shape
private struct ParentStripButtonShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.height / 2)
        let bottom = min(bottomRadius, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + top), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Parent Strip Cursor View
private struct ParentStripCursorView: NSViewRepresentable {
    let cursor: NSCursor
    func makeNSView(context: Context) -> ParentStripCursorNSView {
        ParentStripCursorNSView(cursor: cursor)
    }
    func updateNSView(_ nsView: ParentStripCursorNSView, context: Context) {
        nsView.cursor = cursor
    }
}

// MARK: - Parent Strip Cursor NSView
private final class ParentStripCursorNSView: NSView {
    var cursor: NSCursor {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }
    init(cursor: NSCursor) {
        self.cursor = cursor
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) {
        self.cursor = .pointingHand
        super.init(coder: coder)
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursor)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
