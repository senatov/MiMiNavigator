//
//  TreeRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI
import SwiftyBeaver

struct FavTreeView: View {
    @Binding var file: CustomFile
    @ObservedObject var selected: SelectedDir
    @Binding var expandedFolders: Set<String>

    var isExpanded: Bool {
        expandedFolders.contains(file.pathStr)
    }
    // MARK: -
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Expand/collapse icon rotation animation
                if file.isDirectory {
                    Image(systemName: "chevron.right.circle.fill")
                        .renderingMode(.original)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))  // Вращение
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.3),
                            value: isExpanded
                        )
                        .onTapGesture {
                            toggleExpansion()
                        }
                } else {
                    Image(systemName: "doc")
                        .foregroundColor(.gray)
                }
                // Click to select the file
                let isTheSame = selected.selectedFSEntity.pathStr == file.pathStr
                Text(file.nameStr)
                    .foregroundColor(isTheSame ? .blue : .primary)
                    .onTapGesture {
                        selected.selectedFSEntity = file
                        log.debug("Selected file: \(file.nameStr)")

                    }
                    .contextMenu {
                        TreeViewContextMenu(file: file)
                    }
            }
            .padding(.leading, file.isDirectory ? 5 : 15)
            .font(.system(size: 14, weight: .regular))  // Unified font
            // Subdirectory appearance animation
            if isExpanded, let children = file.children, !children.isEmpty {
                ForEach(children.indices, id: \.self) { index in
                    FavTreeView(
                        file: Binding(
                            get: { file.children![index] },
                            set: { file.children![index] = $0 }
                        ),
                        selected: selected,
                        expandedFolders: $expandedFolders
                    )
                    .padding(.leading, 15)
                    .transition(.opacity.combined(with: .move(edge: .leading)))  // Анимация появления
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)  // Smooth expansion animation
    }
    // MARK: -
    private func toggleExpansion() {
        if isExpanded {
            expandedFolders.remove(file.pathStr)
        } else {
            expandedFolders.insert(file.pathStr)
        }
        log.debug("Toggled folder: \(file.nameStr), expanded: \(isExpanded)")
    }
}
