// BreadCrumbControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import FileModelKit
import SwiftUI

// MARK: - Reusable path control component with edit mode, integrated with AppState.
struct BreadCrumbControlWrapper: View {
    // MARK: - Properties
    @Environment(AppState.self) var appState
    @State private var editedPathStr: String = ""
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isHovering = false

    /// Use computed property to always get current theme (live updates)
    private var colorStore: ColorThemeStore { ColorThemeStore.shared }

    let panelSide: FavPanelSide

    private var themeVersion: Int {
        ColorThemeStore.shared.themeVersion
    }

    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    private var backgroundColor: Color {
        isActivePanel
            ? colorStore.activeTheme.breadcrumbBgActive
            : colorStore.activeTheme.breadcrumbBgInactive
    }

    // MARK: - Constants
    private enum Design {
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1.5  // editing mode border
        static let idleBorderWidth: CGFloat = 0.75  // resting dark-navy border
        static let animationDuration: CGFloat = 0.25

        enum Padding {
            static let horizontal: CGFloat = 1
            static let textFieldPadding: CGFloat = 6
        }

        enum Colors {
            static let editingBackground = Color(nsColor: .controlAccentColor).opacity(0.08)
            static let textFieldBackground = Color(nsColor: .textBackgroundColor)
        }
    }

    // MARK: - Initializer
    init(selectedSide: FavPanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        contentView
            .padding(.horizontal, Design.Padding.horizontal)
            .onHover { isHovering = $0 }
            .background(backgroundShape)
            .overlay(borderShape)
            .frame(height: 34)
            .zIndex(isEditing ? 10 : 0)
            .id("breadcrumb-\(panelSide)-\(themeVersion)")
            .onTapGesture {
                handleWrapperTap()
            }
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .fill(isEditing ? Design.Colors.editingBackground : backgroundColor)
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }

    // MARK: - Border Shape — thin dark-navy border, always visible
    private var borderShape: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .stroke(
                borderColor,
                lineWidth: isEditing ? Design.borderWidth : Design.idleBorderWidth
            )
    }

    // MARK: - Border Color — dark navy, accent when editing
    private var borderColor: Color {
        if isEditing {
            return .accentColor
        }
        // dark navy — same vibe as Total Commander chrome
        return Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.32, alpha: isHovering ? 0.65 : 0.45))
    }

    // MARK: - Helpers
    private func animated(_ action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: Design.animationDuration), action)
    }

    private func handleWrapperTap() {
        guard !isEditing else { return }
        appState.focusedPanel = panelSide
        log.info("Focus set to \(panelSide) panel via wrapper tap")
    }

    private func exitEditingMode() {
        animated {
            isEditing = false
        }
    }

    // MARK: - Editing View
    private var editingView: some View {
        HStack(spacing: 8) {
            PathAutoCompleteField(
                text: $editedPathStr,
                isFocused: $isTextFieldFocused,
                onSubmit: {
                    log.info("Submitted new path: \(editedPathStr)")
                    applyPathUpdate()
                },
                onCancel: {
                    log.info("Exit command received (Escape)")
                    exitEditingMode()
                }
            )
            .onAppear {
                setupEditingMode()
            }
            confirmButton
            cancelButton
        }
        .transition(.opacity)
    }

    // MARK: - Confirm Button
    private var confirmButton: some View {
        Button {
            log.info("Confirmed path editing with checkmark")
            applyPathUpdate()
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(#colorLiteral(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)))
                .font(.system(size: 18, weight: .light))
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help(L10n.PathInput.applyChangesHelp)
    }

    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button {
            log.info("Cancelled path editing with X button")
            exitEditingMode()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(#colorLiteral(red: 0.9, green: 0.25, blue: 0.2, alpha: 1.0)))
                .font(.system(size: 18, weight: .light))
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help(L10n.PathInput.cancelHelp)
    }

    // MARK: - Setup Editing Mode
    private func setupEditingMode() {
        log.info("Entered editing mode")
        editedPathStr = currentPath
        isTextFieldFocused = true

        // Select all text on appearing
        DispatchQueue.main.async {
            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                editor.selectAll(nil)
            }
        }
    }

    // MARK: - Display View
    private var displayView: some View {
        Group {
            if appState.isShowingSearchResults(on: panelSide) {
                searchResultsBreadcrumb
            } else {
                normalBreadcrumb
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    // MARK: - Normal Breadcrumb
    private var normalBreadcrumb: some View {
        BreadCrumbPathControl(selectedSide: panelSide)
            .environment(appState)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { enterEditingMode() }
            )
    }
    // MARK: - Search Results Breadcrumb
    private var searchResultsBreadcrumb: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.orange)
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
            Text("Search Results")
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
            Text("\(appState.displayedFiles(for: panelSide).filter { !ParentDirectoryEntry.isParentEntry($0) }.count) files")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Button {
                appState.clearSearchResults(on: panelSide)
            } label: {
                Label("Clear", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear search results and return to previous directory")
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Enter Editing Mode
    private func enterEditingMode() {
        log.info("Switching to editing mode for side: \(panelSide)")
        Task { @MainActor in
            animated {
                isEditing = true
            }
        }
    }

    // MARK: - Helpers
    private var currentPath: String {
        appState.path(for: panelSide)
    }

    private var navigator: PathNavigationService {
        PathNavigationService.shared(appState: appState)
    }

    private func trimmedEditedPath() -> String {
        editedPathStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateSubmittedPath(_ path: String) -> Bool {
        guard !path.isEmpty else {
            log.warning("Empty path provided, ignoring update")
            return false
        }

        if let remoteURL = URL(string: path), isRemoteInputURL(remoteURL) {
            return true
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.error("Path does not exist: \(path)")
            return false
        }

        return true
    }

    private func isRemoteInputURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "sftp" || scheme == "ftp" || scheme == "afp" || scheme == "smb"
    }

    private func submitPathUpdate(_ path: String) {
        Task {
            log.info("Applying path update for <<\(panelSide)>>: \(path)")
            await navigator.navigate(to: path, side: panelSide)
        }
    }

    // MARK: - Apply Path Update
    private func applyPathUpdate() {
        log.info(#function + " for side <<\(panelSide)>> with path: \(editedPathStr)")

        let trimmedPath = trimmedEditedPath()
        guard validateSubmittedPath(trimmedPath) else {
            exitEditingMode()
            return
        }

        exitEditingMode()
        submitPathUpdate(trimmedPath)
    }
}
