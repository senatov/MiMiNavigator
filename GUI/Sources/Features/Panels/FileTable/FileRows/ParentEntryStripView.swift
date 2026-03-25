//
//  ParentEntryStripView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: ".." row rendered as a slim centered strip.
//               ⌃⌃  /ParentDir (N)  ⌃⌃  — N respects Show Hidden global setting.

import FileModelKit
import SwiftUI

// MARK: - ParentEntryStripView
struct ParentEntryStripView: View {
    let file: CustomFile
    let isSelected: Bool
    let parentURL: URL
    @State private var rowsCount: Int = 0
    @State private var isHovering = false

    // MARK: - label
    private var label: String {
        "\(parentName)   (\(rowsCount) dirs)"
    }

    private let textColor = Color(#colorLiteral(red: 0.25, green: 0.25, blue: 0.27, alpha: 1))
    private let dividerColor = Color(#colorLiteral(red: 0.82, green: 0.82, blue: 0.84, alpha: 1))
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    // Derived
    private var currentURL: URL { file.urlValue }

    // MARK: - Init
    init(
        parentUrl: URL, file: CustomFile, isSelected: Bool,
        onSelect: @escaping (CustomFile) -> Void,
        onDoubleClick: @escaping (CustomFile) -> Void
    ) {
        self.parentURL = parentUrl
        self.file = file
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
    }

    // MARK: - parentName
    private var parentName: String {
        if parentURL.path == "/" {
            return "Root"
        }
        return parentURL.path
    }

    // MARK: - showHidden
    private var showHidden: Bool {
        UserPreferences.shared.snapshot.showHiddenFiles
    }

    // MARK: - bgColor — always neutral, no highlight
    private var bgColor: Color {
        Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
    }

    // MARK: - pebbleActive
    private var pebbleActive: Bool {
        isSelected || isHovering
    }



    // MARK: - body
    var body: some View {
        GeometryReader { geo in
            let _ = log.debug("[ParentEntryStripView] render sel=\(isSelected) hov=\(isHovering)")
            let btnStyle = LiquidGlassButtonStyle(isHighlighted: pebbleActive)
            ZStack(alignment: .leading) {
                bgColor
                // info text on background, offset right of pebble
                Text(label)
                    .font(.system(size: 10, weight: .thin, design: .monospaced))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, geo.size.width * 0.17 + 6)
                // pebble — left-aligned, half width, peeks into header
                HStack(spacing: 0) {
                    Button(action: { onDoubleClick(file) }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(btnStyle.iconColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // icon animation on select/hover
                            .rotationEffect(.degrees(pebbleActive ? -12 : 0))
                            .scaleEffect(pebbleActive ? 1.15 : 1.0)
                            .animation(
                                pebbleActive
                                    ? .interpolatingSpring(stiffness: 180, damping: 8)
                                    : .easeOut(duration: 0.15),
                                value: pebbleActive
                            )
                    }
                    .buttonStyle(btnStyle)
                    .frame(width: geo.size.width * 0.17, height: 25)
                    .offset(y: -3)
                    Spacer()
                }
                // bottom divider
                VStack {
                    Spacer()
                    dividerColor.frame(height: 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 21)
        .zIndex(10)
        .onHover { h in withAnimation(.easeInOut(duration: 0.10)) { isHovering = h } }
        .onTapGesture {
            onSelect(file)
        }
        .onTapGesture(count: 2) {
            onDoubleClick(file)
        }
        .task(id: "\(parentURL.path)-\(showHidden)") {
            await loadParentCount()
        }
    }

    // MARK: - loadParentCount
    private func loadParentCount() async {
        let count: Int
        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            if showHidden {
                count =
                    items.filter { url in
                        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    }
                    .count
                log.debug(#function)
            } else {
                count =
                    items.filter { url in
                        do {
                            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                            let isDirectory = values.isDirectory ?? false
                            let isHidden = values.isHidden ?? false
                            return isDirectory && !isHidden
                        } catch {
                            return false
                        }
                    }
                    .count
                log.debug(#function)
            }
            await MainActor.run {
                rowsCount = count
            }
        } catch {
            await MainActor.run {
                rowsCount = 0
            }
        }
    }
}
