//
//  EditablePathControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct EditablePathControlWrapper: View {
    @Binding var path: String
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 5)
    }

    private var editingView: some View {
        HStack {
            TextField("Enter path", text: $path)
                .textFieldStyle(.plain)
                .padding(6)
                .background(.white)
                .focused($isTextFieldFocused)
                .onAppear { isTextFieldFocused = true }
                .onExitCommand { isEditing = false }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = false
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .transition(.opacity)
    }

    private func handlePathChanged(_ newPath: String) {
        self.path = newPath
    }

    private var pathControlView: some View {
        EditablePathControlView(path: $path, onPathSelected: handlePathChanged)
    }

    private var displayView: some View {
        pathControlView
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing = true
                }
            }
            .transition(.opacity)
    }
}
