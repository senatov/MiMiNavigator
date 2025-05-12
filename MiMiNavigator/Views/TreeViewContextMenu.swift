//
//  TreeViewContextMenu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

struct TreeViewContextMenu: View {
    let file: CustomFile

    var body: some View {
        Group {
            Button(action: {
                log.debug("Copy action for \(file.nameStr)")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(action: {
                log.debug("Rename action for \(file.nameStr)")
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }

            Button(action: {
                log.debug("Delete action for \(file.nameStr)")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .foregroundColor(.red)

            Button(action: {
                log.debug("More info action for \(file.nameStr)")
            }) {
                Label("More Info", systemImage: "info.circle")
            }
        }
    }
}
