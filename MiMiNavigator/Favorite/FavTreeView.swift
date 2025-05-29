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
    @EnvironmentObject var appState: AppState
    @Binding var file: CustomFile
    @Binding var expandedFolders: Set<String>

    // MARK: -
    private var fileIcon: some View {
        Group {
            if file.isDirectory {
                Image(systemName: "chevron.right.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
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
        }
    }

    // MARK: -
    private var fileNameText: some View {
        let isTheSame = appState.selectedDir.selectedFSEntity?.pathStr == file.pathStr
        return Text(file.nameStr)
            .foregroundColor(isTheSame ? .blue : .primary)
            .onTapGesture {
                appState.selectedDir.selectedFSEntity = file
                log.info("Selected file: \(file.nameStr)")
            }
            .contextMenu {
                TreeViewContextMenu(file: file)
            }
    }

    // MARK: -
    private var fileRow: some View {
        HStack {
            fileIcon
            fileNameText
        }
        .padding(.leading, file.isDirectory ? 5 : 15)
        .font(.system(size: 14, weight: .regular))
    }

    // MARK: -
    var body: some View {
        VStack(alignment: .leading) {
            fileRow
            childrenList
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    // MARK: -
    var isExpanded: Bool {
        expandedFolders.contains(file.pathStr)
    }

    // MARK: -
    private var childrenList: some View {
        Group {
            if isExpanded, let children = file.children, !children.isEmpty {
                ForEach(children.indices, id: \.self) { index in
                    FavTreeView(
                        file: Binding(
                            get: { file.children![index] },
                            set: { file.children![index] = $0 }
                        ),
                        expandedFolders: $expandedFolders
                    )
                    .padding(.leading, 15)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
    }

    // MARK: -
    private func toggleExpansion() {
        if isExpanded {
            expandedFolders.remove(file.pathStr)
        } else {
            expandedFolders.insert(file.pathStr)
        }
        log.info("Toggled folder: \(file.nameStr), expanded: \(isExpanded)")
    }
}
