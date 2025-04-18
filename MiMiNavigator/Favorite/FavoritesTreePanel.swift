//
//  FavoritesTreePanel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 19.04.25.
//  Copyright © 2025 Senatov. All rights reserved.
//


import AppKit
import SwiftUI
import SwiftyBeaver

struct FavoritesTreePanel: View {
    @Binding var favTreeStruct: [CustomFile]
    @Binding var selectedFile: CustomFile?

    var body: some View {
        TreeView(files: $favTreeStruct, selectedFile: $selectedFile)
            .padding(3)
            .frame(maxWidth: 230)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.141, green: 0.396, blue: 0.564, alpha: 1)))
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3), value: favTreeStruct)
    }
}