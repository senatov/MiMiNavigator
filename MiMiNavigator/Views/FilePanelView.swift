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
            Table(files, selection: $selectedFile) {
                TableColumn("Name") { file in
                    rowContent(for: file) {
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(file.nameStr)
                                .foregroundColor(
                                    file.isDirectory
                                        ? Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1))
                                        : file.isSymbolicDirectory
                                            ? Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
                                            : Color(#colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1))
                                )
                        }
                    }
                }
                TableColumn("Size") { file in
                    rowContent(for: file) {
                        Text(file.formattedSize)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .frame(width: 80, alignment: .trailing)
                    }
                }
                TableColumn("Modified") { file in
                    rowContent(for: file) {
                        Text(file.modifiedDateFormatted)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(width: 120, alignment: .leading)
                    }
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

    private func rowContent<Content: View>(for file: CustomFile, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedFile == file.id ? Color.blue.opacity(0.2) : Color.clear)
    }
}
