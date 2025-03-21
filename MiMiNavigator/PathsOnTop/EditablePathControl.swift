import AppKit
//
//  EditablePathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import SwiftUI

struct EditablePathControl: View {
    @Binding var path: String
    var onPathSelected: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(pathComponents(), id: \.path) { item in
                Button {
                    path = item.path
                    onPathSelected(item.path)
                } label: {
                    HStack(spacing: 4) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .transition(.opacity)
                            .animation(.easeInOut, value: path)

                        Text(item.title)
                            .foregroundStyle(.primary)
                            .font(.callout)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .animation(.easeInOut, value: path)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
        )
    }

        // Вспомогательная структура для элементов пути
    struct PathItem {
        let title: String
        let path: String
        let icon: NSImage
    }

        // Создание элементов пути (без изменения состояния внутри тела View)
    private func pathComponents() -> [PathItem] {
        let components = URL(fileURLWithPath: path).pathComponents.filter { $0 != "/" }
        var items: [PathItem] = []
        var currentPath = "/"

        for component in components {
            currentPath.append(component + "/")
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)

            items.append(PathItem(title: component, path: currentPath, icon: icon))
        }

        return items
    }
}
