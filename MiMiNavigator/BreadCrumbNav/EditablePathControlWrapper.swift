//
//  EditablePathControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
/// -
struct EditablePathControlWrapper: View, CustomStringConvertible {

    @StateObject var selection = SelectedDir()
    @State private var editedPathStr: String = ""
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    var selectedSide: PanelSide

    // MARK: - Initialization
    init(selectedSide: PanelSide) {
        self.selectedSide = selectedSide
    }

    // MARK: -
    init(selStr: String, selectedSide: PanelSide) {
        self.selectedSide = selectedSide
    }

    // MARK: -
    var body: some View {
        HStack {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 7.0, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }

    // MARK: -
    private var editingView: some View {
        HStack {
            TextField("Enter path", text: $editedPathStr)
                .textFieldStyle(.plain)
                .padding(6)
                .background(.white)
                .focused($isTextFieldFocused)
                .onAppear {
                    log.debug("Entered editing mode")
                    editedPathStr = selection.selectedFSEntity?.pathStr ?? ""
                    isTextFieldFocused = true
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }
                .onExitCommand {
                    log.debug("Exit command received (Escape)")
                    isEditing = false
                }
                .onSubmit {
                    log.debug("Submitted new path: \(editedPathStr)")
                    selection.selectedFSEntity = CustomFile(path: editedPathStr)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditing = false
                    }
                }

            Button {
                log.debug("Confirmed path editing with checkmark")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = false
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.accentColor)
            }

            Button {
                log.debug("Cancelled path editing with X button")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .renderingMode(.original)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .transition(.opacity)
    }

    // MARK: -
    private var pathControlView: some View {
        EditablePathControlView(selectedDir: selection, panelSide: selectedSide)
    }

    // MARK: -
    private var displayView: some View {
        pathControlView
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .font(.system(size: 13, weight: .light, design: .default))
            .contentShape(Rectangle())
            .onTapGesture {
                log.debug("Switching to editing mode")
                withAnimation(.easeInOut(duration: 0.25)) {
                    isEditing = true
                }
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.25), value: isEditing)
    }

    // MARK: -
    nonisolated var description: String {
        "description"
    }
}
