// RecentSessionsTableView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Recent Sessions table for Connect to Server dialog.
//   3-column resizable, sortable table (Date | Session | Status).
//   Built like FileTableView: ResizableDivider headers, row layout matches header widths.

import SwiftUI

// MARK: - Recent Sessions Table View
struct RecentSessionsTableView: View {
    let servers: [RemoteServer]
    @Binding var selectedID: RemoteServer.ID?
    @Bindable var layout: SessionColumnLayout
    @State private var sortKey: SessionSortKey = .date
    @State private var sortAscending: Bool = false

    private var sortedServers: [RemoteServer] {
        servers.sorted { a, b in
            let result: Bool
            switch sortKey {
            case .date:
                result = (a.lastConnected ?? .distantPast) < (b.lastConnected ?? .distantPast)
            case .session:
                result = a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            case .status:
                result = a.lastResult.rawValue < b.lastResult.rawValue
            }
            return sortAscending ? result : !result
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            sessionList
        }
    }

    // MARK: - Header Row
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Date column (fixed)
            sessionHeaderCell(.date)
                .frame(width: widthFor(.date))
            ResizableDivider(
                width: bindingFor(.date),
                min: 40, max: 200,
                onEnd: { layout.saveWidths() }
            )
            // Session column (flexible)
            sessionHeaderCell(.session)
                .frame(minWidth: 60, maxWidth: .infinity)
            ResizableDivider(
                width: bindingFor(.status),
                min: 40, max: 150,
                onEnd: { layout.saveWidths() }
            )
            // Status column (fixed)
            sessionHeaderCell(.status)
                .frame(width: widthFor(.status))
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .background(DesignTokens.warmWhite)
    }

    // MARK: - Header Cell
    private func sessionHeaderCell(_ col: SessionColumnID) -> some View {
        HStack(spacing: 3) {
            Text(col.title)
                .font(.system(size: 14, weight: sortKey.rawValue == col.rawValue ? .semibold : .regular, design: .default))
                .foregroundStyle(sortKey.rawValue == col.rawValue ? .primary : .secondary)
                .lineLimit(1)
            if sortKey.rawValue == col.rawValue {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: col.alignment)
        .contentShape(Rectangle())
        .onTapGesture { toggleSort(col) }
    }

    // MARK: - Selection colors (matches FileRow)
    private static let activeFill = Color(nsColor: .selectedContentBackgroundColor)
    private static let inactiveFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

    // MARK: - Session List
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedServers) { server in
                    let isSelected = selectedID == server.id
                    sessionRow(server, isSelected: isSelected)
                        .background(isSelected ? Self.activeFill : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = server.id }
                    Divider().padding(.leading, 4)
                }
            }
        }
        .background(DesignTokens.warmWhite)
    }

    // MARK: - Session Row
    private func sessionRow(_ server: RemoteServer, isSelected: Bool) -> some View {
        let textColor: Color = isSelected ? .white : .primary
        let secondaryTextColor: Color = isSelected ? .white.opacity(0.85) : .secondary

        return HStack(spacing: 0) {
            // Date
            Text(server.formattedLastConnected)
                .font(.system(size: 13, design: .default))
                .foregroundStyle(secondaryTextColor)
                .frame(width: widthFor(.date), alignment: .leading)
                .lineLimit(2)
            Spacer().frame(width: 4)
            // Session
            VStack(alignment: .leading, spacing: 1) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                Text(server.sessionSummary)
                    .font(.system(size: 11, design: .default))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 4)
            // Status
            VStack(spacing: 2) {
                Image(systemName: server.lastResult.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : colorForResult(server.lastResult))
                Text(server.lastResult.rawValue)
                    .font(.system(size: 10, design: .default))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: widthFor(.status), alignment: .center)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    // MARK: - Helpers

    private func widthFor(_ col: SessionColumnID) -> CGFloat {
        layout.columns.first(where: { $0.id == col })?.width ?? col.defaultWidth
    }

    private func bindingFor(_ col: SessionColumnID) -> Binding<CGFloat> {
        Binding(
            get: { widthFor(col) },
            set: { layout.setWidth($0, for: col) }
        )
    }

    private func toggleSort(_ col: SessionColumnID) {
        let key = SessionSortKey(rawValue: col.rawValue) ?? .date
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = col == .date ? false : true
        }
    }

    private func colorForResult(_ result: ConnectionResult) -> Color {
        switch result {
        case .none:       return .secondary
        case .success:    return .green
        case .authFailed: return .orange
        case .timeout:    return .yellow
        case .refused:    return .red
        case .error:      return .red
        }
    }
}
