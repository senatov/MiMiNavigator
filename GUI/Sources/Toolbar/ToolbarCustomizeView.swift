// ToolbarCustomizeView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root dialog for toolbar customization.

import SwiftUI

// MARK: - Toolbar Customize View
struct ToolbarCustomizeView: View {

    @State private var store = ToolbarStore.shared
    @State private var filterText = ""
    @State private var showReset = false
    @State private var dragPreview: ToolbarItemID? = nil
    @State private var dragPool: ToolbarItemID? = nil

    var body: some View {
        VStack(spacing: 0) {
            TCV_Header()
            Divider()
            TCV_PreviewStrip(store: store, dragPreview: $dragPreview, dragPool: $dragPool)
            Divider()
            TCV_MenuBarRow(store: store)
            Divider()
            TCV_FilterField(text: $filterText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            Divider()
            TCV_Palette(store: store, filterText: filterText, dragPreview: $dragPreview, dragPool: $dragPool)
            Divider()
            TCV_Footer(store: store, onReset: { showReset = true })
        }
        .frame(width: 360, height: 500)
        .background(DialogColors.base)
        .confirmationDialog("Reset Toolbar", isPresented: $showReset) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Toolbar order and visibility will be reset to factory defaults.")
        }
    }
}
