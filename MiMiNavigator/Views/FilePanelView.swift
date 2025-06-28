//
//  FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import AppKit
import SwiftUI

struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    var side: PanelSide
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    let fetchFiles: @concurrent (PanelSide) async -> Void

    var body: some View {
        let currentPath = appState.pathURL(for: side)
        VStack {
            EditablePathControlWrapper(appState: appState, selectedSide: side)
                .onChange(of: currentPath) {
                    guard let url = currentPath else {
                        log.warning("Tried to set nil path for side \(side)")
                        return
                    }
                    Task {
                        appState.updatePath(url.absoluteString, on: side)
                        await fetchFiles(side)
                    }
                }
           let files = sortedFiles
            Table(files, selection: .constant(nil)) {
                TableColumn("Name") { file in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(file.nameStr)
                            .foregroundColor(file.isDirectory ? .cyan : .primary)
                    }
                }
                TableColumn("Size") { file in
                    Text(file.formattedSize)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                TableColumn("Modified") { file in
                    Text(file.modifiedDateFormatted)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .border(Color.secondary)
        }
        .frame(width: side == .left ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2) : nil)
    }
}

private extension FilePanelView {
    var sortedFiles: [CustomFile] {
        let files = appState.displayedFiles(for: side)
        let directories = files.filter { $0.isDirectory || $0.isSymbolicDirectory }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        let others = files.filter { !($0.isDirectory || $0.isSymbolicDirectory) }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        return directories + others
    }
}
