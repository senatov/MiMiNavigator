//
//  DividerView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.07.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

struct DividerView: View {
    let geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    @EnvironmentObject var appState: AppState
    let onDrag: (DragGesture.Value) -> Void
    let onDragEnd: () -> Void

    // MARK: -
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(.ultraThinMaterial)
                .frame(width: 6)
                .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newWidth = leftPanelWidth + value.translation.width
                    let minPanelWidth: CGFloat = 100
                    let maxPanelWidth = geometry.size.width - 100
                    if newWidth > minPanelWidth, newWidth < maxPanelWidth {
                        leftPanelWidth = newWidth
                        onDrag(value)
                    }
                }
                .onEnded { _ in
                    UserDefaults.standard.set(
                        leftPanelWidth,
                        forKey: "leftPanelWidth"
                    )
                    onDragEnd()
                }
        )
        .onTapGesture(count: 2) {
            leftPanelWidth = geometry.size.width / 2
            UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
        }
        .onHover { isHovering in
            DispatchQueue.main.async {
                isHovering ? NSCursor.resizeLeftRight.push() : NSCursor.pop()
            }
        }
    }
}
