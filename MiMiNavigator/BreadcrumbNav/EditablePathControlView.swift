import AppKit
//
//  EditablePathControlView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import SwiftUI
import SwiftyBeaver

struct EditablePathControlView: View {
    @Binding var path: String
    var onPathSelected: (String) -> Void

    var body: some View {
        HStack(spacing: 2) {
            NavMnu()
            Spacer()
            ForEach(Array(pathComponents().enumerated()), id: \.1.path) { index, item in
                if index > 0 {
                    Image(systemName: "arrowtriangle.right")
                        .foregroundColor(.gray)
                        .onTapGesture {
                            log.debug("Forward: clicked breadcrumb separator")
                        }
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        path = item.path
                        onPathSelected(item.path)
                    }
                }) {
                    DirIcon(item: item, path: path)
                }
                .buttonStyle(.plain)
            }
            Mnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }

    // Вспомогательная структура для элементов пути
    struct EditablePathItem: Hashable {
        let title: String
        let path: String
        let icon: NSImage
    }

    // Генерация элементов пути
    private func pathComponents() -> [EditablePathItem] {
        let url = URL(fileURLWithPath: path)
        var components = url.pathComponents
        if components.first == "/" { components.removeFirst() }

        var currentPath = "/"
        return components.map { component in
            currentPath = (currentPath as NSString).appendingPathComponent(component)
            let icon = NSWorkspace.shared.icon(forFile: currentPath)
            icon.size = NSSize(width: 16, height: 16)

            return EditablePathItem(title: component, path: currentPath, icon: icon)
        }
    }

}

struct Mnu2: View {
    var body: some View {
        Menu {
            Button(
                "Properties",
                action: {
                    log.debug("Properties menu selected")
                }
            )
            Button(
                "Open in Finder",
                action: {
                    log.debug("Open in Finder menu selected")
                }
            )
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
        }
        .menuStyle(.borderlessButton)
    }
}

struct NavMnu: View {
    var body: some View {
        HStack(spacing: 4) {
            // Navigation buttons
            ButtonNavOnBreadCamp()
        }
        .padding(.leading, 6)
    }
}

struct DirIcon: View {
    let item: EditablePathControlView.EditablePathItem
    let path: String

    var body: some View {
        let isSelected = path == item.path
        let gradientColors =
            isSelected
            ? [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
            : [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]

        return HStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(item.title)
                .foregroundStyle(.primary)
                .font(.callout)
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .gray.opacity(isSelected ? 0.4 : 0), radius: 4, x: 0, y: 2)
        )
    }
}



#Preview {
    EditablePathControlView(path: .constant("/Users/senat/Downloads/Telegram Desktop")) { selectedPath in
        print("Path selected: \(selectedPath)")
    }
    .frame(height: 36)
    .padding()
}
