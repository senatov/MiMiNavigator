//
//  EditablePathControlWrapper.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

struct EditablePathControlWrapper: View {
    @Binding var path: String
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack {
            if isEditing {
                TextField("Enter path", text: $path)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onAppear {
                        isTextFieldFocused = true
                    }
                    .onExitCommand {
                        isEditing = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .layoutPriority(1)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.4), value: isEditing)
                 Button(action: {
                    withAnimation {
                        isEditing = false
                    }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Button(action: {
                    withAnimation {
                        isEditing = false 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            } else {
                EditablePathControlView(path: $path) { newPath in
                    path = newPath
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)  // Добавлено для равномерного распределения
                .background(Color.clear)
                .gesture(
                    TapGesture()
                        .onEnded {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isEditing = true
                            }
                        }
                )
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.2), value: isEditing)
            }
        }
        .padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.2))
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isEditing)
        )
        .padding(.bottom, 4)
        .padding(.top, 5)
    }
}
