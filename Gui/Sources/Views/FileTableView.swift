//
//  FileTableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct FileTableView: View {
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void

    var body: some View {
        Table(files, selection: $selectedID) {
            TableColumn("Name") { file in
                FileRowView(file: file, isSelected: selectedID == file.id) {
                    onSelect(file)
                }
            }
            TableColumn("Size") { file in
                Text(file.formattedSize)
                    .foregroundColor(.primary)
                    .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .trailing)
            }
            TableColumn("Modified") { file in
                Text(file.modifiedDateFormatted)
                    .foregroundColor(.primary)
                    .frame(width: FilePanelStyle.modifiedColumnWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .border(Color.secondary)
    }
}
