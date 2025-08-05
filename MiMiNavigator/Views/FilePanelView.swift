//
//  FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import AppKit
import SwiftUI

// MARK: -
struct FilePanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFile: CustomFile.ID?
    var geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    let fetchFiles: @Sendable @concurrent (PanelSide) async -> Void
    let panelSide: PanelSide



    // MARK: - Initializer
    init(
        selectedSide: PanelSide,
        geometry: GeometryProxy,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void
    ) {
        log.info("FilePanelView init")
        self.panelSide = selectedSide
        self.geometry = geometry
        self._leftPanelWidth = leftPanelWidth
        self.fetchFiles = fetchFiles
    }


    // MARK: - View
    var body: some View {
        let currentPath = appState.pathURL(for: panelSide)
        VStack {
            BreadCrumbControlWrapper(selectedSide: panelSide)
                .onChange(of: currentPath) {
                    guard let url = currentPath else {
                        log.warning("Tried to set nil path for side \(panelSide)")
                        return
                    }
                    Task {
                        appState.updatePath(url.absoluteString, for: panelSide)
                        await fetchFiles(panelSide)
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
                                    ? Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1))
                                    : file.isSymbolicDirectory
                                        ? Color(#colorLiteral(red: 0.07102862641, green: 0.400000006, blue: 0.2974898127, alpha: 1))
                                        : Color(#colorLiteral(red: 0.004859850742, green: 0.09608627111, blue: 0.5749928951, alpha: 1))
                            )
                    }
                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .background(
                        selectedFile == file.id
                            ? Color(red: 0.82, green: 0.91, blue: 0.99) // Windows 11 selection blue
                            : Color.clear
                    )
                    .cornerRadius(4)
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
        .frame(width: panelSide == .left ? (leftPanelWidth > 0 ? leftPanelWidth : geometry.size.width / 2) : nil)
    }

    // MARK: - Helpers
    private var sortedFiles: [CustomFile] {
        let files = appState.displayedFiles(for: panelSide)
        let directories = files.filter { $0.isDirectory || $0.isSymbolicDirectory }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        let others = files.filter { !($0.isDirectory || $0.isSymbolicDirectory) }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        return directories + others
    }
}