// FileInfoRow.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Row component displaying file metadata with icon

import SwiftUI
import AppKit

// MARK: - File Info Row
/// Displays file information including icon, path, name, date and size
struct FileInfoRow: View {
    let title: String
    let url: URL
    let name: String
    let size: Int64
    let date: Date?
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            fileIcon
            fileDetails
            Spacer()
        }
    }
    
    // MARK: - Private Views
    private var fileIcon: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: 48, height: 48)
            .cornerRadius(4)
    }
    
    private var fileDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleText
            PathWithHighlight(path: parentPath)
            nameText
            dateText
            sizeText
        }
    }
    
    private var titleText: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
    }
    
    private var nameText: some View {
        Text(name)
            .font(.system(size: 11))
            .foregroundStyle(.primary)
            .lineLimit(2)
    }
    
    private var dateText: some View {
        Text(formattedDate)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
    
    private var sizeText: some View {
        Text(formattedSize)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Computed Properties
private extension FileInfoRow {
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    var parentPath: String {
        url.deletingLastPathComponent().path
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = date else { return "" }
        return Self.dateFormatter.string(from: date)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMMM yyyy 'at' HH:mm:ss"
        return formatter
    }()
}

// MARK: - Preview
#Preview {
    FileInfoRow(
        title: "Copying",
        url: URL(fileURLWithPath: "/Users/senat/Downloads/test.mp4"),
        name: "test.mp4",
        size: 1_234_567,
        date: Date()
    )
    .padding()
    .frame(width: 400)
}
