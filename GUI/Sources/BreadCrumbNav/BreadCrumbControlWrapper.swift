// BreadCrumbControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Reusable path control component with edit mode, integrated with AppState.
struct BreadCrumbControlWrapper: View {
    // MARK: - Properties
    @Environment(AppState.self) var appState
    @State private var editedPathStr: String = ""
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isHovering = false

    let panelSide: PanelSide

    // MARK: - Constants
    private enum Design {
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1.5
        static let idleBorderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 7
        static let shadowOpacityHovering: CGFloat = 0.18
        static let shadowOpacityIdle: CGFloat = 0.12
        static let animationDuration: CGFloat = 0.25
        static let fontSize: CGFloat = 13

        enum Padding {
            static let horizontal: CGFloat = 1
            static let vertical: CGFloat = 2
            static let textFieldPadding: CGFloat = 6
        }

        enum Colors {
            static let editingBackground = Color(nsColor: .controlAccentColor).opacity(0.08)
            static let idleBackground = Color(nsColor: .windowBackgroundColor)
            static let textFieldBackground = Color(nsColor: .textBackgroundColor)
            static let hoverBorderOpacity: CGFloat = 0.5
            static let idleBorderOpacity: CGFloat = 0.3
        }
    }

    // MARK: - Initializer
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        // Throttled logging removed - only log on state changes
        return
            contentView
            .padding(.horizontal, Design.Padding.horizontal)
            .padding(.vertical, Design.Padding.horizontal)
            .onHover { hovering in
                isHovering = hovering
            }
            .background(backgroundShape)
            .overlay(borderShape)
            .shadow(
                color: .secondary.opacity(
                    isHovering ? Design.shadowOpacityHovering : Design.shadowOpacityIdle
                ),
                radius: Design.shadowRadius,
                x: 1,
                y: 1
            )
            .padding(.vertical, Design.Padding.vertical)
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

    // MARK: - Background Shape
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .fill(isEditing ? Design.Colors.editingBackground : Design.Colors.idleBackground)
    }

    // MARK: - Border Shape
    private var borderShape: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .stroke(
                borderColor,
                lineWidth: isEditing ? Design.borderWidth : Design.idleBorderWidth
            )
    }

    // MARK: - Border Color
    private var borderColor: Color {
        if isEditing {
            return .accentColor
        } else {
            return Color.blue.opacity(
                isHovering ? Design.Colors.hoverBorderOpacity : Design.Colors.idleBorderOpacity
            )
        }
    }

    // MARK: - Editing View
    private var editingView: some View {
        return HStack(spacing: 8) {
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
                .font(.system(size: 18, weight: .medium))
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
                .font(.system(size: 18, weight: .medium))
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
        return BreadCrumbPathControl(selectedSide: panelSide)
            .environment(appState)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .font(.system(size: Design.fontSize, weight: .light, design: .default))
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        // Double-click enters editing mode
                        enterEditingMode()
                    }
            )
            .transition(.opacity.combined(with: .scale))
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
        panelSide == .left ? appState.leftPath : appState.rightPath
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
            appState.updatePath(trimmedPath, for: panelSide)
            
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
