import AppKit
//
//  EditablePathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import SwiftUI

struct EditablePathControlView: View {
    @Binding var path: String
    var onPathSelected: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(pathComponents(), id: \PathItem.path) { item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        path = item.path
                        onPathSelected(item.path)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .frame(width: 16, height: 16)

                        Text(item.title)
                            .foregroundStyle(.primary)
                            .font(.callout)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: path == item.path
                                        ? [Color.orange.opacity(0.4), Color.orange.opacity(0.2)]
                                        : [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .orange.opacity(path == item.path ? 0.4 : 0), radius: 4, x: 0, y: 2)
                    )
                    .animation(.easeInOut(duration: 0.2), value: path)
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
    private struct PathItem: Hashable {
        let title: String
        let path: String
        let icon: NSImage
    }

    // Генерация элементов пути
    private func pathComponents() -> [PathItem] {
        let url = URL(fileURLWithPath: path)
        var components = url.pathComponents
        if components.first == "/" { components.removeFirst() }

        var currentPath = "/"
        return components.map { component in
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)

            return PathItem(title: component, path: currentPath, icon: icon)
        }
    }
}
