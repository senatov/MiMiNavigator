    //
    //  DisplayPatView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 25.03.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

struct DisplayPathView: View {
    let path: String
    @Binding var isEditing: Bool
    
    var body: some View {
        Text(path)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.white)
            .gesture(
                TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditing = true
                    }
                }
            )
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isEditing)
        
    }
}

#Preview {
    DisplayPathPreviewWrapper()
}

private struct DisplayPathPreviewWrapper: View {
    @State private var isEditing = false
    
    var body: some View {
        DisplayPathView(path: "/Users/username/Documents", isEditing: $isEditing)
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
