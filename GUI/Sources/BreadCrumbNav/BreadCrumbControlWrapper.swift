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

    let panelSide: PanelSide

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
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        // Capture themeVersion to force view refresh on theme changes
        let themeVersion = ColorThemeStore.shared.themeVersion

        // Compute background color inline to ensure reactivity
        let isActive = appState.focusedPanel == panelSide
        let bgColor =
            isActive
            ? colorStore.activeTheme.breadcrumbBgActive
            : colorStore.activeTheme.breadcrumbBgInactive

        // DEBUG: log every body eval
        //log.debug("[BreadCrumbWrapper] body eval: themeVersion=\(themeVersion), isActive=\(isActive), bgColor=\(bgColor.description)")

        return
            contentView
            .padding(.horizontal, Design.Padding.horizontal)
            .onHover { hovering in isHovering = hovering }
            .background(
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .fill(isEditing ? Design.Colors.editingBackground : bgColor)
            )
            .overlay(borderShape)
            .frame(height: 34)
            .zIndex(isEditing ? 10 : 0)
            .id("breadcrumb-\(panelSide)-\(themeVersion)")  // force FULL redraw on theme change
            .padding(.horizontal, Design.Padding.horizontal)
            .onTapGesture {
                if !isEditing {
                    appState.focusedPanel = panelSide
                    log.info("Focus set to \(panelSide) panel via wrapper tap")
                }
            }
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
                    withAnimation(.easeInOut(duration: Design.animationDuration)) {
                        isEditing = false
                    }
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
            withAnimation(.easeInOut(duration: Design.animationDuration)) {
                isEditing = false
            }
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
            withAnimation(.easeInOut(duration: Design.animationDuration)) {
                isEditing = true
            }
        }
    }

    // MARK: - Helpers
    private var currentPath: String {
        appState.path(for: panelSide)
    }

    // MARK: - Apply Path Update
    private func applyPathUpdate() {
        log.info(#function + " for side <<\(panelSide)>> with path: \(editedPathStr)")

        // Trim whitespace and validate path
        let trimmedPath = editedPathStr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPath.isEmpty else {
            log.warning("Empty path provided, ignoring update")
            withAnimation(.easeInOut(duration: Design.animationDuration)) {
                isEditing = false
            }
            return
        }

        // Validate path exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: trimmedPath) else {
            log.error("Path does not exist: \(trimmedPath)")
            withAnimation(.easeInOut(duration: Design.animationDuration)) {
                isEditing = false
            }
            return
        }

        withAnimation(.easeInOut(duration: Design.animationDuration)) {
            isEditing = false
        }

        Task {
            log.info("Applying path update for <<\(panelSide)>>: \(trimmedPath)")

            // Update path through AppState to record in navigation history
            let newURL = URL(fileURLWithPath: trimmedPath)
            appState.updatePath(newURL, for: panelSide)

            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: trimmedPath)
                await appState.scanner.resetRefreshTimer(for: .left)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
                log.info("Left panel updated to: \(trimmedPath)")
            } else {
                await appState.scanner.setRightDirectory(pathStr: trimmedPath)
                await appState.scanner.resetRefreshTimer(for: .right)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
                log.info("Right panel updated to: \(trimmedPath)")
            }
        }
    }
}
