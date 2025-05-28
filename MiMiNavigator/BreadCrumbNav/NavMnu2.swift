//
//  NavMnu2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

// MARK: -
struct NavMnu2: View {
    var body: some View {
        Menu {
            Button(
                "Properties",
                action: {
                    log.info("Properties menu selected")
                }
            )
            Button(
                "Open in Finder",
                action: {
                    log.info("Open in Finder menu selected")
                }
            )
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
        }
        .menuStyle(.borderlessButton)
    }
}
