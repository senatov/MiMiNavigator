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
    /// Pale-yellow background, light pale-blue text, no selection highlight.
    struct TopParentDirectoryControl: View {

        let file: CustomFile
        let isSelected: Bool
        let onSelect: (CustomFile) -> Void
        let onOpenParent: (CustomFile) -> Void

        @State private var isHovering: Bool = false

        private let paleBlue = Color(#colorLiteral(red: 0.826266822, green: 0.8257061658, blue: 0.95, alpha: 1))
        private let paleYellow = Color(#colorLiteral(red: 1, green: 0.98, blue: 0.82, alpha: 1))
        private let paleYellowHover = Color(#colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1))

        private var parentDirectoryName: String {
            file.urlValue.deletingLastPathComponent().lastPathComponent
        }

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
                    .resizable()
                    .frame(width: 12, height: 11)
                    .foregroundStyle(paleBlue)

                Text("..")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(paleBlue)

                Text(parentDirectoryName)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(paleBlue)
                    .lineLimit(1)

                if let size = parentSizeString {
                    Text("(\(size))")
                        .font(.system(size: 10, weight: .ultraLight))
                        .foregroundStyle(paleBlue.opacity(0.7))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22)
            .background(isHovering ? paleYellowHover : paleYellow)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .onTapGesture { onSelect(file) }
            .onTapGesture(count: 2) { onOpenParent(file) }
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
                .frame(width: 500)
                .padding()
            }
        }
    #endif
