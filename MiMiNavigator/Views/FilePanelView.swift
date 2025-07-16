//
//  FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import AppKit
import SwiftUI

// MARK: -
struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    var currSide: PanelSide
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    let fetchFiles: @Sendable (PanelSide) async -> Void

    // MARK: -
    var body: some View {
        let currentPath = appState.pathURL(for: currSide)
        VStack {
            EditablePathControlWrapper(appState: appState, selectedSide: currSide)
                .onChange(of: currentPath) {
                    guard let url = currentPath else {
                        log.warning("Tried to set nil path for side \(currSide)")
                        return
                    }
                    Task {
                        appState.updatePath(url.absoluteString, on: currSide)
                        await fetchFiles(currSide)
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
                            .foregroundColor(
                                file.isDirectory
                                    ? Color(#colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
                                    : Color(#colorLiteral(red: 0.004859850742, green: 0.09608627111, blue: 0.5749928951, alpha: 1))
                            )
                    }
                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                }
                TableColumn("Size") { file in
                    Text(file.formattedSize)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                }
                TableColumn("Modified") { file in
                    Text(file.modifiedDateFormatted)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(width: 120, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .border(Color.secondary)
        }
        .frame(width: currSide == .left ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2) : nil)
    }
}

// MARK: -
extension FilePanelView {
    fileprivate var sortedFiles: [CustomFile] {
        let files = appState.displayedFiles(for: currSide)
        let directories = files.filter { $0.isDirectory || $0.isSymbolicDirectory }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        let others = files.filter { !($0.isDirectory || $0.isSymbolicDirectory) }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        return directories + others
    }
}
