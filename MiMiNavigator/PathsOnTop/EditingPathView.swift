//
//  EditingPathView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Subviews
struct EditingPathView: View {
    @Binding var path: String
    @Binding var isEditing: Bool
    @FocusState var isTextFieldFocused: Bool

    var body: some View {
        HStack {
            TextField("Enter path", text: $path)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(6)
                .background(Color.white)
                .focused($isTextFieldFocused)
                .onAppear { isTextFieldFocused = true }
                .onExitCommand { isEditing = false }

            Button {
                withAnimation { isEditing = false }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { isEditing = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: isEditing)
    }
}
