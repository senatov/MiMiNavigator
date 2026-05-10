// GeoTagBadgeView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Small globe overlay badge for geotagged images.
//   Shown at bottomLeading of the file icon ZStack.

import SwiftUI

// MARK: - GeoTag Globe Badge
struct GeoTagBadgeView: View {

    // MARK: - Body
    var body: some View {
        Image(systemName: "globe.europe.africa.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color(#colorLiteral(red: 0.9056425032, green: 0.7600209422, blue: 0.9686274529, alpha: 1)))
            .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.5)
    }
}
