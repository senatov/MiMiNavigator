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
    @Binding var selectedFile: CustomFile?
    @Binding var expandedFolders: Set<String>

    var isExpanded: Bool {
        expandedFolders.contains(file.path)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Анимация вращения значка раскрытия
                if file.isDirectory {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))  // Вращение
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
                    .foregroundColor(selectedFile?.path == file.path ? .blue : .primary)
                    .onTapGesture {
                        selectedFile = file
                        log.debug("Selected file: \(file.name)")
                    }
                    .contextMenu {
                        TreeViewContextMenu(file: file)
                    }
            }
            .padding(.leading, file.isDirectory ? 5 : 15)
            .font(.system(size: 14, weight: .regular))  // Унифицированный шрифт

            // Анимация появления поддиректорий
            if isExpanded, let children = file.children, !children.isEmpty {
                ForEach(children.indices, id: \.self) { index in
                    FavTreeView(
                        file: Binding(
                            get: { file.children![index] },
                            set: { file.children![index] = $0 }
                        ),
                        selectedFile: $selectedFile,
                        expandedFolders: $expandedFolders
                    )
                    .padding(.leading, 15)
                    .transition(.opacity.combined(with: .move(edge: .leading)))  // Анимация появления
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)  // Плавная анимация раскрытия
    }

    private func toggleExpansion() {
        if isExpanded {
            expandedFolders.remove(file.path)
        } else {
            expandedFolders.insert(file.path)
        }
        log.debug("Toggled folder: \(file.name), Expanded: \(isExpanded)")
    }
}

// MARK: - Preview
struct PreviewTreeRowView: View {
    @State private var previewSelectedFile: CustomFile? = nil
    @State private var previewExpandedFolders: Set<String> = []

    @State private var previewFile: CustomFile = CustomFile(
        name: "Root",
        path: "/Root",
        isDirectory: true,
        children: [
            CustomFile(
                name: "Folder 1",
                path: "/Root/Folder1",
                isDirectory: true,
                children: [
                    CustomFile(name: "File 1", path: "/Root/Folder1/File1", isDirectory: false),
                    CustomFile(name: "File 2", path: "/Root/Folder1/File2", isDirectory: false),
                ]
            ),
            CustomFile(name: "Folder 2", path: "/Root/Folder2", isDirectory: true, children: []),
        ]
    )

    var body: some View {
        FavTreeView(
            file: $previewFile,
            selectedFile: $previewSelectedFile,
            expandedFolders: $previewExpandedFolders
        )
        .padding()
        frame(width: 300, height: 400) // Увеличили высоту до 400
    }
}

struct TreeRowView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewTreeRowView()
    }
}
