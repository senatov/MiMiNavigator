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

    var body: some View {
        HStack {
            if isEditing {
                TextField("Enter path", text: $path, onCommit: {
                    isEditing = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                EditablePathControl(path: $path) { newPath in
                    path = newPath
                }
                .onTapGesture {
                    isEditing = true
                }
            }
        }
    }
}
