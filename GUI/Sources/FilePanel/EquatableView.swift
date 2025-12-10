//
// EquatableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Equatable wrapper to avoid unnecessary recomputation on divider drags.
/// This helps optimize performance when dealing with large lists where parent
/// view updates frequently but child content remains stable.
struct EquatableView<Value: Hashable, Content: View>: View {
    let value: Value
    let content: () -> Content
    
    @MainActor 
    var body: some View { 
        content().id(value) 
    }
}
