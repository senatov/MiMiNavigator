// MultiRenamePreviewView.swift
// MiMiNavigator

import SwiftUI

// MARK: - Multi Rename Preview View
struct MultiRenamePreviewView: View {
    let items: [MultiRenamePreviewItem]
    @State private var selection: MultiRenamePreviewItem.ID?

    var body: some View {
        Table(items, selection: $selection) {
            TableColumn("Old name") { item in Text(item.originalName).lineLimit(1) }
            TableColumn("New name") { item in
                Text(item.proposedName)
                    .lineLimit(1)
                    .foregroundStyle(item.issue == nil ? (item.isChanged ? Color.primary : Color.secondary) : Color.red)
            }
            TableColumn("Status") { item in
                Text(item.issue ?? (item.isChanged ? "Ready" : "Unchanged"))
                    .lineLimit(1)
                    .foregroundStyle(item.issue == nil ? Color.secondary : Color.red)
            }
            .width(min: 110, ideal: 150)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}
