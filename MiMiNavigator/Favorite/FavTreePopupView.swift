//
//  FavTreePopupView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 19.04.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

struct FavTreePopupView<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding()
            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                    log.debug("Popup canceled")
                }
                Button("OK") {
                    isPresented = false
                    log.debug("Popup confirmed")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}
