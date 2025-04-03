//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import AppKit
import SwiftUI

struct EditablePathControlView: View {
    @Binding var path: String
    var onPathSelected: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(pathComponents(), id: \.path) { item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if path != item.path {
                            path = item.path
                        }
                        onPathSelected(item.path)
                    }
                }) {
                    Label(item.title, systemImage: "folder")
                        .fontWeight(isSelected(item) ? .bold : .regular)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.primary)
                        .font(.callout)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: isSelected(item)
                                        ? [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
                                        : [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .gray.opacity(isSelected(item) ? 0.4 : 0), radius: 4, x: 0, y: 2)
                                .animation(.easeInOut(duration: 0.15), value: isSelected(item))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }

    private func isSelected(_ item: EditablePathItem) -> Bool {
        URL(fileURLWithPath: path).standardized.path == item.path
    }

    private struct EditablePathItem: Hashable {
        let title: String
        let path: String
    }

    private func pathComponents() -> [EditablePathItem] {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL
        let components = standardized.pathComponents.filter { $0 != "/" }

        var currentPath = "/"
        return components.map { component in
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            return EditablePathItem(title: component, path: currentPath)
        }
    }
}

#Preview {
    EditablePathPreviewWrapper()
}

private struct EditablePathPreviewWrapper: View {
    @State private var currentPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents")
        .path

    var body: some View {
        EditablePathControlView(path: $currentPath) { selected in
            print("Path selected:", selected)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
