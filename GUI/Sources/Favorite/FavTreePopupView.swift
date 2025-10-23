//
//  FavTreePopupView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.02.2025.
//  Updated for macOS 2026 Figma style on 09.10.2025
//

import AppKit
import SwiftUI

@MainActor
struct FavTreePopupView: View {
    // MARK: - Environment / Dependencies
    @EnvironmentObject var appState: AppState
    @Binding var file: CustomFile
    @Binding var expandedFolders: Set<String>
    let manageWindow: Bool  // kept for source compatibility, ignored
    @StateObject private var popoverController = FavTreePopoverController()
    @State private var headerButtonAnchor: NSView?

    // MARK: - Init
    init(
        file: Binding<CustomFile>,
        expandedFolders: Binding<Set<String>>,
        manageWindow: Bool = true
    ) {
        self._file = file
        self._expandedFolders = expandedFolders
        self.manageWindow = manageWindow
        log.info("FavTreePopupView init for file \(file.wrappedValue.nameStr), side <<\(appState.focusedPanel)>>")
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Glass background (macOS 2026 Figma style: subtle, not balloon-like)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 8) {
                header
                Divider().opacity(0.25)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        fileRow
                        childrenList
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(10)
        }
        .frame(minWidth: 340, minHeight: 420)
        // Create standalone dialog window only when requested
        .onAppear {
            // No window creation here; this view is used as NSPopover content.
            appState.focusedPanel = appState.focusedPanel
        }
        // ESC to close
        .onExitCommand {
            log.info("ESC pressed → closing FavTreePopover")
            popoverController.close()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Text("Favorites")
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
            Button(action: {
                Task { @MainActor in
                    do {
                        // Present as a sheet anchored to our window; the anchor view is available if needed for popovers
                        let data = try await grantAccessToVolumeAndSaveBookmark()
                        log.info("User granted access. Bookmark bytes: \(data.count)")
                    } catch {
                        log.error("Grant access failed: \(error.localizedDescription)")
                    }
                }
            }) {
                Image(systemName: "externaldrive.badge.plus")
                    .help("Allow access to a volume…")
            }
            .background(
                AnchorCaptureView { nsView in
                    self.headerButtonAnchor = nsView
                    log.debug("Captured header button NSView for precise popover anchoring")
                }
            )
            .buttonStyle(.borderless)
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)
    }

    private var fileIcon: some View {
        Group {
            if file.isDirectory || file.isSymbolicDirectory {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(.accent)
                    .frame(width: 14, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log.debug("Icon tap → toggleExpansion() for \(file.nameStr)")
                        toggleExpansion()
                    }
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .leading)
            }
        }
    }

    private var fileNameText: some View {
        // Selected state: compare with appState
        let isCurrent = (appState.selectedDir.selectedFSEntity?.pathStr == file.pathStr)
        return Text(file.nameStr)
            .font(.system(size: 13))
            .foregroundColor(isCurrent ? .accentColor : .primary)
            .contentShape(Rectangle())
            .onTapGesture {
                log.info("Favorites select: \(file.nameStr)")
                Task { @MainActor in
                    appState.selectedDir.selectedFSEntity = file
                    await appState.scanner.resetRefreshTimer(for: .left)
                    await appState.scanner.resetRefreshTimer(for: .right)
                    await appState.scanner.refreshFiles(currSide: .left)
                    await appState.scanner.refreshFiles(currSide: .right)
                }
            }
            .contextMenu {
                TreeViewContextMenu(file: file)
            }
    }

    private var fileRow: some View {
        HStack(spacing: 6) {
            fileIcon
            fileNameText
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            // Very subtle selection/expanded cue, no heavy buttons
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isExpanded ? Color.accentColor.opacity(0.10) : .clear)
        )
        .contentShape(Rectangle())
        .padding(.leading, (file.isDirectory || file.isSymbolicDirectory) ? 5 : 15)
        .font(.system(size: 14, weight: .regular))
    }

    private var childrenList: some View {
        Group {
            if isExpanded, let children = file.children, !children.isEmpty {
                ForEach(children.indices, id: \.self) { index in
                    FavTreePopupView(
                        file: Binding(
                            get: { file.children![index] },
                            set: { file.children![index] = $0 }
                        ),
                        expandedFolders: $expandedFolders,
                        manageWindow: false  // prevent nested windows
                    )
                    .environmentObject(appState)
                    .padding(.leading, 14)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: - State & Logic
    var isExpanded: Bool {
        expandedFolders.contains(file.pathStr)
    }

    private func toggleExpansion() {
        log.info("toggleExpansion for \(file.nameStr), current: \(isExpanded)")
        guard file.isDirectory || file.isSymbolicDirectory else {
            log.info("Ignored toggle: not a directory/symbolic directory")
            return
        }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.7, blendDuration: 0.2)) {
            if isExpanded {
                expandedFolders.remove(file.pathStr)
            } else {
                expandedFolders.insert(file.pathStr)
            }
        }
        log.debug("Toggled folder: \(file.nameStr), expanded -> \(isExpanded)")
    }

}
