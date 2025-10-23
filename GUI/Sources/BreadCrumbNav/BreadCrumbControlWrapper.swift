//
//  EditablePathControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Reusable path control component with edit mode, integrated with AppState.
struct BreadCrumbControlWrapper: View {
    @EnvironmentObject var appState: AppState
    @State private var editedPathStr: String = ""
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isHovering = false
    var side: PanelSide? = nil
    
        // Effective side used by the wrapper; falls back to AppState.focusedPanel if not provided
    private var effectiveSide: PanelSide { side ?? appState.focusedPanel }


    // MARK: - Body
    var body: some View {
        log.debug(#function + " — effectiveSide=\(effectiveSide)")
        return HStack {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .padding(.horizontal, 1)
        .padding(.vertical, 1)
        .onHover { hovering in
            isHovering = hovering
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                // Use pale yellow when editing, otherwise subtle platform background
                .fill(
                    isEditing
                        ? FilePanelStyle.orangeSelRowStroke.opacity(0.6)
                        : Color(nsColor: NSColor.windowBackgroundColor))
        )
        .overlay(
            // Blue border when editing, subtle gray when idle; no internal separators
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isEditing ? Color.accentColor : Color.blue.opacity(isHovering ? 0.5 : 0.3),  //no
                    lineWidth: isEditing ? 1.5 : 1)
        )
        .shadow(color: .secondary.opacity(isHovering ? 0.18 : 0.12), radius: 7, x: 1, y: 1)
        .padding(.vertical, 2)
        .padding(.horizontal, 1)
    }

    // MARK: - Editing View
    private var editingView: some View {
        log.debug(#function + " — effectiveSide=\(effectiveSide)")
        return HStack {
            TextField("Enter path", text: $editedPathStr)
                .textFieldStyle(.plain)
                .padding(6)
                .background(.white)
                .focused($isTextFieldFocused)
                .onAppear {
                    log.info("Entered editing mode")
                    editedPathStr = currentPath
                    isTextFieldFocused = true
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }
                .onExitCommand {
                    log.info("Exit command received (Escape)")
                    isEditing = false
                }
                .onSubmit {
                    log.info("Submitted new path: \(editedPathStr)")
                    applyPathUpdate()
                }
            Button {
                log.info("Confirmed path editing with checkmark")
                applyPathUpdate()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse)
            }
            Button {
                log.info("Cancelled path editing with X button")
                withAnimation { isEditing = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.gray.opacity(0.7))
                    .symbolEffect(.pulse)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Display View
    private var displayView: some View {
        log.debug(#function + " — effectiveSide=\(effectiveSide)")
        return BreadCrumbPathControl(selectedSide: effectiveSide)
            .environmentObject(appState)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .font(.system(size: 13, weight: .light, design: .default))
            .contentShape(Rectangle())
            .onTapGesture {
                log.info(#function)
                Task { @MainActor in
                    log.info("Switching to editing mode")
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditing = true
                    }
                }
            }
            .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Helpers
    private var currentPath: String {
        effectiveSide == .left ? appState.leftPath : appState.rightPath
    }

    // MARK: -
    private func applyPathUpdate() {
        log.debug(#function + " — effectiveSide=\(effectiveSide), path=\(editedPathStr)")
        withAnimation { isEditing = false }
        Task {
            if effectiveSide == .left {
                appState.leftPath = editedPathStr
                await appState.scanner.setLeftDirectory(pathStr: editedPathStr)
                await appState.refreshLeftFiles()
            } else {
                appState.rightPath = editedPathStr
                await appState.scanner.setRightDirectory(pathStr: editedPathStr)
                await appState.refreshRightFiles()
            }
        }
    }
}