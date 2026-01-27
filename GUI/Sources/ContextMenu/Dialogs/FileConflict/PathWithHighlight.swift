// PathWithHighlight.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: View component displaying path with highlighted last folder

import SwiftUI

// MARK: - Path with Highlighted Folder
/// Displays file path with the last folder component highlighted in orange
struct PathWithHighlight: View {
    let path: String
    
    // MARK: - Body
    var body: some View {
        let components = path.split(separator: "/").map(String.init)
        
        HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    separatorText
                }
                componentText(component, isLast: index == components.count - 1)
            }
        }
    }
    
    // MARK: - Private Views
    private var separatorText: some View {
        Text("/")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
    
    private func componentText(_ component: String, isLast: Bool) -> some View {
        Text(component)
            .font(.system(size: 10))
            .foregroundStyle(isLast ? Color.orange : .secondary)
    }
}

// MARK: - Preview
#Preview {
    PathWithHighlight(path: "/Users/senat/Downloads/TestFolder")
        .padding()
}
