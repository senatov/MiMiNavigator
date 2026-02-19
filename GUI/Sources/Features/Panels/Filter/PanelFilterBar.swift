// PanelFilterBar.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Inline file filter — HIG-style search field + history popover with per-item delete

import AppKit
import SwiftUI

// MARK: - Main SwiftUI view
struct PanelFilterBar: View {
    @Binding var query: String
    let panelSide: PanelSide

    @StateObject private var history: PanelFilterHistory
    @State private var showHistory = false
    @FocusState private var isFocused: Bool

    init(query: Binding<String>, panelSide: PanelSide) {
        self._query = query
        self.panelSide = panelSide
        self._history = StateObject(wrappedValue: PanelFilterHistory(panelSide: panelSide.rawValue))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 7)

            // Text input
            TextField("Filter", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .padding(.horizontal, 5)
                .onSubmit {
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        history.add(query)
                    }
                }

            // Clear button
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .transition(.opacity)
            }

            // History button
            if !history.entries.isEmpty {
                Button { showHistory.toggle() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showHistory ? 180 : 0))
                        .animation(.easeInOut(duration: 0.15), value: showHistory)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 7)
                .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                    historyPopover
                }
            } else {
                Spacer().frame(width: 7)
            }
        }
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isFocused
                        ? Color(#colorLiteral(red: 0.25, green: 0.55, blue: 1.0, alpha: 1.0)).opacity(0.8)
                        : Color(nsColor: .separatorColor).opacity(0.6),
                    lineWidth: isFocused ? 1.5 : 0.5
                )
        )
        .animation(.easeInOut(duration: 0.12), value: query.isEmpty)
        .animation(.easeInOut(duration: 0.12), value: isFocused)
    }

    // MARK: - History popover
    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(history.entries, id: \.self) { entry in
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Text(entry)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Per-item delete
                    Button {
                        history.remove(entry)
                        if history.entries.isEmpty { showHistory = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from history")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .onTapGesture {
                    query = entry
                    showHistory = false
                }

                if entry != history.entries.last {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
        .frame(minWidth: 180, maxWidth: 240)
        .padding(.vertical, 4)
    }
}
