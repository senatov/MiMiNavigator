//
// FavTreePopup.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//

import SwiftUI

// MARK: -
struct FavTreePopup: View {
    @EnvironmentObject var appState: AppState
    @Binding var files: [CustomFile]
    @Binding var isPresented: Bool
    @State private var expandedFolders: Set<String> = []
    let panelSide: PanelSide

    // MARK: -
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
                .padding(.horizontal, 8)
            fileListView
        }
        .frame(minWidth: 320, idealWidth: 420, maxWidth: 560)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .task { @MainActor in
            appState.focusedPanel = panelSide
        }
        .onAppear {
            #if DEBUG
                log.debug("FavTreePopup appeared with \(files.count) files")
            #endif
        }
        // ESC to close popup
        .onExitCommand {
            log.info("ESC pressed → closing FavTreePopup")
            isPresented = false
        }
    }

    // MARK: -
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
            
            Text("Favorites")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer(minLength: 0)
            
            Text("\(files.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                )
            
            Button(action: {
                Task { @MainActor in
                    do {
                        let data = try await grantAccessToVolumeAndSaveBookmark()
                        log.info("User granted access. Bookmark bytes: \(data.count)")
                    } catch {
                        log.error("Grant access failed: \(error.localizedDescription)")
                    }
                }
            }) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .help("Grant access to a volume…")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: -
    private var fileListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach($files) { $file in
                    FavTreePopupView(
                        file: $file, 
                        expandedFolders: $expandedFolders,
                        isPresented: $isPresented
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: 520, alignment: .leading)
        .onChange(of: files.count) { _, newCount in
            #if DEBUG
                log.debug("FavTree — files changed: \(newCount)")
            #endif
        }
    }
}
