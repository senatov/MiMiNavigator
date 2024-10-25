// ToolbarButton.swift
// Reusable toolbar button component with customizable title and action
//
//  Created by Iakov Senatov on 25.10.24.

import SwiftUI

/// A reusable toolbar button with a given title and action
struct ToolbarButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
