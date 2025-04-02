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
                LogMan.log.debug("Copy action for \(file.name)")
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(action: {
                LogMan.log.debug("Rename action for \(file.name)")
            }) {
                Label("Rename", systemImage: "square.and.pencil")
            }

            Button(action: {
                LogMan.log.debug("Delete action for \(file.name)")
            }) {
                Label("Delete", systemImage: "trash")
            }
            .foregroundColor(.red)

            Button(action: {
                LogMan.log.debug("More info action for \(file.name)")
            }) {
                Label("More Info", systemImage: "info.circle")
            }
        }
    }
}
