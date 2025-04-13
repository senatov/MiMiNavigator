//
//  TreeRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI
import SwiftyBeaver

// MARK: -
struct FavTreeRowView: View {
    @Binding var file: CustomFile
    @Binding var selectedFav: CustomFile?
    @Binding var expandedFolders: Set<String>

    var isExpanded: Bool {
        expandedFolders.contains(file.path)
    }
    // MARK: -
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Анимация вращения значка раскрытия
                if file.isDirectory {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)).opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.3), value: isExpanded)
                        .onTapGesture {
                            toggleExpansion()
                        }
                } else {

                    Image(systemName: "doc")
                        .foregroundColor(.gray)
                }
                // Клик для выбора файла
                Text(file.name)
                    .foregroundColor(selectedFav?.path == file.path ? .blue : .primary)
                    .onTapGesture {
                        selectedFav = file
                        log.debug("Selected tree menu item:' \(file.name)'")
                    }
                    .contextMenu {
                        TreeViewContextMenu(file: file)
                    }
            }
            .padding(.leading, file.isDirectory ? 5 : 15)
            .font(.system(size: 14, weight: .light))  // Унифицированный шрифт
            // Анимация появления поддиректорий
            if isExpanded, let children = file.children, !children.isEmpty {
                ForEach(children.indices, id: \.self) { index in
                    FavTreeRowView(
                        file: Binding(
                            get: { file.children![index] },
                            set: { file.children![index] = $0 }
                        ),
                        selectedFav: $selectedFav,
                        expandedFolders: $expandedFolders
                    )
                    .padding(.leading, 15)
                    .transition(.opacity.combined(with: .move(edge: .leading)))  // Анимация появления
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)  // Плавная анимация раскрытия
    }
    // MARK: -
    private func toggleExpansion() {
        log.debug("toggleExpansion(file)")
        if isExpanded {
            expandedFolders.remove(file.path)
        } else {
            expandedFolders.insert(file.path)
        }
        log.debug("Toggled folder: \(file.name), Expanded: \(isExpanded)")
    }
}

