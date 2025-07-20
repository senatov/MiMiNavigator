//
//  EditablePathControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Reusable path control component with edit mode, integrated with AppState.
struct EditablePathControlWrapper: View {
    @EnvironmentObject var appState: AppState
    @State private var editedPathStr: String = ""
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    let selectedSide: PanelSide


    // MARK: - Body
    var body: some View {
        log.debug("EditablePathControlWrapper body for side \(selectedSide)")
        return HStack {
            if isEditing {
                editingView
            }
            else {
                displayView
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 7, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }

    // MARK: - Editing View
    private var editingView: some View {
        log.info(#function)
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
            }
            Button {
                log.info("Cancelled path editing with X button")
                withAnimation { isEditing = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .transition(.opacity)
    }


    // MARK: - Display View
    private var displayView: some View {
        log.info(#function)
        return EditablePathControl()
            .environmentObject(appState)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .font(.system(size: 13, weight: .light, design: .default))
            .contentShape(Rectangle())
            .onTapGesture {
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
        selectedSide == .left ? appState.leftPath : appState.rightPath
    }


    // MARK: -
    private func applyPathUpdate() {
        log.info(#function)
        withAnimation { isEditing = false }
        Task {
            if selectedSide == .left {
                appState.leftPath = editedPathStr
                await appState.scanner.setLeftDirectory(pathStr: editedPathStr)
                await appState.refreshLeftFiles()
            }
            else {
                appState.rightPath = editedPathStr
                await appState.scanner.setRightDirectory(pathStr: editedPathStr)
                await appState.refreshRightFiles()
            }
        }
    }

}