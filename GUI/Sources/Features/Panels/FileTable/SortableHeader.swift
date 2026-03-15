// SortableHeader.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column header with separate sort arrow click target
//              and title double-click for auto-fit.

import SwiftUI

// MARK: - SortableHeader
/// Column header with separate sort arrow click target and title double-click for auto-fit.
/// Sort arrow shows bold black highlight on hover (same affordance as ResizableDivider).
struct SortableHeader: View {
    let title: String
    let icon: String?
    let sortKey: SortKeysEnum?
    let currentKey: SortKeysEnum
    let ascending: Bool
    /// Called when sort arrow is clicked
    let onSort: (() -> Void)?
    /// Called on double-click of the title area (auto-fit column width)
    let onAutoFit: (() -> Void)?

    init(
        title: String,
        icon: String? = nil,
        sortKey: SortKeysEnum?,
        currentKey: SortKeysEnum,
        ascending: Bool,
        onSort: (() -> Void)? = nil,
        onAutoFit: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.sortKey = sortKey
        self.currentKey = currentKey
        self.ascending = ascending
        self.onSort = onSort
        self.onAutoFit = onAutoFit
    }

    private var isActive: Bool {
        guard let sk = sortKey else { return false }
        return currentKey == sk
    }

    private var activeColor: Color {
        Color(nsColor: NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.7, alpha: 1.0))
    }

    var body: some View {
        HStack(spacing: 0) {
            titleArea
            Spacer(minLength: 0)
            if sortKey != nil {
                SortArrowButton(
                    isActive: isActive,
                    ascending: ascending,
                    onSort: onSort
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    // MARK: - Title Area (double-click only → auto-fit, no sort)
    @ViewBuilder
    private var titleArea: some View {
        if let iconName = icon {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                .help(title)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onAutoFit?() }
                .onTapGesture(count: 1) { /* swallow single tap — no sort here */ }
        } else {
            Text(title)
                .font(.system(size: 13, weight: isActive ? TableHeaderStyle.sortActiveWeight : .regular))
                .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                .padding(.leading, 2)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onAutoFit?() }
                .onTapGesture(count: 1) { /* swallow single tap — no sort here */ }
        }
    }
}
