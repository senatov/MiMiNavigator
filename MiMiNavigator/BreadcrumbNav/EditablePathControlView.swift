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

enum PanelSide {
    case left, right
}

struct EditablePathControlView: View {
    @Binding var path: String
    let side: PanelSide
    var onPathSelected: (String) -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            NavMnu()
            Spacer()
            ForEach(Array(pathComponents().enumerated()), id: \.1.path) { index, item in
                if index > 0 {
                    Image(systemName: "chevron.forward.dotted.chevron.forward")
                        .onTapGesture {
                            log.debug("Forward: clicked breadcrumb separator")
                        }
                        .symbolRenderingMode(.multicolor)
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        path = item.path
                        onPathSelected(item.path)
                    }
                }) {
                    DirIcon(item: item, path: path, side: side)
                }
                .buttonStyle(.plain)
            }
            Mnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
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
        log.debug(#function)
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
            FavButtonPopupTopPanel()
        }
        .padding(.leading, 6)
    }
}

struct DirIcon: View {
    let item: EditablePathControlView.EditablePathItem
    let path: String
    let side: PanelSide
    
    var body: some View {
        let isSelected = path == item.path
        let baseColor: Color = side == .left ? .green : .blue
        let gradientColors = isSelected
        ? [baseColor.opacity(0.2), baseColor.opacity(0.1)]
        : [baseColor.opacity(0), baseColor.opacity(0.01)]
        return HStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .renderingMode(.original)
                .frame(width: 16, height: 16)
            
            Text(item.title)
                .foregroundStyle(.primary)
                .font(.callout)
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .gray.opacity(isSelected ? 0.4 : 0), radius: 7.0, x: 0, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        EditablePathControlView(path: .constant("/Users/senat/Downloads"), side: .left) { selectedPath in
            print("Left panel selected: \(selectedPath)")
        }
        EditablePathControlView(path: .constant("/Users/senat/Documents"), side: .right) { selectedPath in
            print("Right panel selected: \(selectedPath)")
        }
    }
    .frame(height: 90)
    .padding()
}
