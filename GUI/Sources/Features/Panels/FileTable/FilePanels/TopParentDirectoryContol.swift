    //
    //  TopParentDirectoryContol.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 13.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import FileModelKit
    import FilesProvider
    import Foundation
    import SwiftUI

    /// Parent directory navigation control (".." row).
    /// This view is responsible only for rendering and user interaction.
    /// It intentionally contains no scanning or filesystem logic.
    struct TopParentDirectoryControl: View {

        /// Parent entry file model (represents "..")
        let file: CustomFile

        /// Indicates whether this row is currently selected
        let isSelected: Bool

        /// Selection callback
        let onSelect: (CustomFile) -> Void

        /// Double‑click callback (navigate to parent directory)
        let onOpenParent: (CustomFile) -> Void

        /// Hover state for subtle UI feedback
        @State private var isHovering: Bool = false

        /// Name of the parent directory
        private var parentDirectoryName: String {
            file.urlValue.deletingLastPathComponent().lastPathComponent
        }

        /// Best‑effort formatted size of the parent directory (fast metadata only)
        private var parentSizeString: String? {
            let parentURL = file.urlValue.deletingLastPathComponent()
            if let values = try? parentURL.resourceValues(forKeys: [.fileAllocatedSizeKey]),
                let size = values.fileAllocatedSize
            {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
            return nil
        }

        var body: some View {
            HStack(spacing: 6) {

                Image(systemName: "arrowshape.turn.up.left.fill")
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95))

                Text("..")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95))

                Text(parentDirectoryName)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95))
                    .lineLimit(1)

                if let size = parentSizeString {
                    Text("(\(size))")
                        .font(.system(size: 10, weight: .ultraLight))
                        .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.7))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22)
            .background(
                Group {
                    if isSelected {
                        Color.accentColor.opacity(0.25)
                    } else if isHovering {
                        Color.accentColor.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.85)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                onSelect(file)
            }
            .onTapGesture(count: 2) {
                onOpenParent(file)
            }
        }
    }

    // MARK: - Preview
    #if DEBUG
        struct TopParentDirectoryControl_Previews: PreviewProvider {

            static var previews: some View {
                TopParentDirectoryControl(
                    file: CustomFile(name: "..", path: "/"),
                    isSelected: false,
                    onSelect: { _ in },
                    onOpenParent: { _ in }
                )
                .frame(width: 400)
                .padding()
            }
        }
    #endif
