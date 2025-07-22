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

    init(file: Binding<CustomFile>, expandedFolders: Binding<Set<String>>) {
        log.info("FavTreeView init")
        self._file = file
        self._expandedFolders = expandedFolders
    }

    // MARK: -
    var body: some View {
        log.info(#function)
        return VStack(alignment: .leading) {
            fileRow
            childrenList
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }


    // MARK: -
    private var fileIcon: some View {
        Group {
            if file.isDirectory {
                Image(systemName: "chevron.right.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .onTapGesture {
                        Task { @MainActor in
                            toggleExpansion()
                        }
                    }
            }
            else {
                Image(systemName: "doc")
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: -
    private var fileNameText: some View {
        log.info(#function + " for \(file.nameStr)")
        let isTheSame = appState.selectedDir.selectedFSEntity?.pathStr == file.pathStr
        return Text(file.nameStr)
            .foregroundColor(isTheSame ? .blue : .primary)
            .onTapGesture {
                Task { @MainActor in
                    appState.selectedDir.selectedFSEntity = file
                    appState.showFavTreePopup = false
                    await appState.scanner.resetRefreshTimer(for: .left)
                    await appState.scanner.resetRefreshTimer(for: .right)
                    await appState.scanner.refreshFiles(currSide: .left)
                    await appState.scanner.refreshFiles(currSide: .right)
                    log.info("Favorites->selected Dir: \(file.nameStr)")
                }
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.3)) {
            if isExpanded {
                expandedFolders.remove(file.pathStr)
            }
            else {
                expandedFolders.insert(file.pathStr)
            }
        }
        log.info("Toggled folder: \(file.nameStr), expanded: \(isExpanded)")
    }
}
