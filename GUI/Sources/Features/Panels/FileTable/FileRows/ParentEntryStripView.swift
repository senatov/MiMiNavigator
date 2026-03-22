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
    private let chevronColor = Color(#colorLiteral(red: 0.50, green: 0.50, blue: 0.54, alpha: 1))
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

    // MARK: - bgColor
    private var bgColor: Color {
        isHovering
            ? Color(#colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1))
            : Color(#colorLiteral(red: 0.97, green: 0.97, blue: 0.97, alpha: 1))
    }

    // MARK: - body
    var body: some View {
        ZStack {
            bgColor
            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(chevronColor)
                Spacer()
                Text(label)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(chevronColor)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            VStack {
                Spacer()
                dividerColor.frame(height: 0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 21)
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
