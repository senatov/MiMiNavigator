//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK:  -
/// Bottom toolbar button — native macOS bordered bezel with visible edges
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    // MARK: -
    var body: some View {
        Button(action: {
            log.debug("DownToolbarButton pressed: \(title)")
            action()
        }) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 90)
        }
        // Native macOS bezel — rounded corners, visible border, system hover/press
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.primary)
        .help(title)
    }
}
