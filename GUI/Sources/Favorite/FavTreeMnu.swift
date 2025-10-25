//
//  FavTreeMnu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//

import SwiftUI

struct FavTreeMnu: View {
    @EnvironmentObject var appState: AppState
    @Binding var files: [CustomFile]
    @State private var expandedFolders: Set<String> = []
    let panelSide: PanelSide

    // MARK: -
    var body: some View {
        log.debug(#function)
        return VStack(alignment: .leading, spacing: 0) {
            headerView
            dividerView
            fileListView
        }
        .frame(width: 450)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(#colorLiteral(red: 1.0, green: 0.64705884, blue: 0.0, alpha: 0.01)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                )
        )
        .padding()
        .task { @MainActor in
            appState.focusedPanel = panelSide
        }
    }

    // MARK: -
    private var headerView: some View {
        log.debug(#function)
        return Text("Favorites:")
            .font(.headline)
            .foregroundColor(Color(#colorLiteral(red: 0.06274510175, green: 0, blue: 0.1921568662, alpha: 1)))
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: -
    private var dividerView: some View {
        log.debug(#function)
        return Divider()
            .padding(.horizontal)
            .padding(.vertical, 6)
    }

    // MARK: -
    private var fileListView: some View {
        // Log outside the render hot path (on appear/changes)
        let _ = {
            #if DEBUG
                log.debug("\(#function) — \(files.count) files")
            #endif
        }()

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach($files) { $file in
                    FavTreePopupView(file: $file, expandedFolders: $expandedFolders)
                }
            }
            .padding(.horizontal, 12)  // Figma spacing
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Lightweight "liquid glass" container
        .background(Material.thin)  // вместо .regularMaterial; совместимо на macOS
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)  // subtle outline per macOS design
        )
        .onAppear {
            #if DEBUG
                log.debug("FavTree — appear with \(files.count) files")
            #endif
        }
        .onChange(of: files.count) { _, newCount in
            #if DEBUG
                log.debug("FavTree — files changed: \(newCount)")
            #endif
        }
        .padding(.bottom, 8)
    }
}
