//
//  PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: -
struct PanelFileTableSection: View {
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
        
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]
        
    var body: some View {
        log.info(#function + " for side \(panelSide)")
        return FileTableView(
            files: files,
            selectedID: $selectedID,
            onSelect: { _ in } // selection handled below
        )
        .coordinateSpace(name: "fileTableSpace")
        .onPreferenceChange(RowRectPreference.self) { value in
            rowRects = value
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { g in
                if let id = selectedID, let rect = rowRects[id] {
                    let y = rect.minY
                    let h = rect.height
                    let w = g.size.width
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(#colorLiteral(red: 1.0, green: 1.0, blue: 0.94, alpha: 1))) // very-light yellow background
                            .frame(width: w, height: h)
                            .offset(x: 0, y: y)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1) // blue border
                            .frame(width: w, height: h)
                            .offset(x: 0, y: y)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        // Unified click area for the table — keep previous behavior and style
        .simultaneousGesture(
            TapGesture().onEnded {
                onPanelTap(panelSide)
                log.debug("table tap (simultaneous) on side \(panelSide)")
            }
        )
        // React to selection changes
        .onChange(of: selectedID, initial: false) { _, newValue in
            log.debug("on onChange on table, side \(panelSide)")
            if let id = newValue, let file = files.first(where: { $0.id == id }) {
                log.debug("Row selected: id=\(id) on side \(panelSide)")
                onSelect(file)
            } else {
                log.debug("Selection cleared on \(panelSide)")
            }
        }
        // Navigation with arrow keys — same as before
        .onMoveCommand { direction in
            switch direction {
            case .up,
                 .down:
                log.debug("Move command: \(direction) on side \(panelSide)")
                DispatchQueue.main.async {
                    if let id = selectedID, let file = files.first(where: { $0.id == id }) {
                        onSelect(file)
                    } else {
                        log.debug("Move command but no selection on \(panelSide)")
                    }
                }
                    
            default:
                log.debug("on onMoveCommand on table, side \(panelSide)")
            }
        }
    }
}
