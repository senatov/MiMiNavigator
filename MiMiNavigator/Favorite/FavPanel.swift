// FavoritesPanel.swift
// MiMiNavigator

//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

// Description: Enhanced to include Finder-style items and JSON-based state persistence

import SwiftUI
import SwiftyBeaver

// MARK: - A sidebar panel displaying user's favorite locations in a Finder-style interface.
struct FavPanel: View {
    @AppStorage("favoritesState") private var favoritesStateJsonStr: String = ""  // JSON storage for favorites state

    // MARK: - Define Finder-style favorite items
    private var favoriteItems: [FavoriteItem] = [
        FavoriteItem(name: "AirDrop", icon: "airplane.circle.fill"),
        FavoriteItem(name: "Recent", icon: "clock.fill"),
        FavoriteItem(name: "Applications", icon: "folder.fill"),
        FavoriteItem(name: "Home", icon: "house.fill"),
        FavoriteItem(name: "Desktop", icon: "desktopcomputer"),
        FavoriteItem(name: "Documents", icon: "doc.text.fill"),
        FavoriteItem(name: "Downloads", icon: "arrow.down.circle.fill"),
        FavoriteItem(name: "Music", icon: "music.note"),
        FavoriteItem(name: "Pictures", icon: "photo"),
        FavoriteItem(name: "iCloud Drive", icon: "icloud.and.arrow.down"),
        FavoriteItem(name: "Shared", icon: "person.2.fill"),
        FavoriteItem(name: "Network", icon: "network"),
    ]

    // MARK: - Convert JSON string to a dictionary for accessing favorites state
    private var favoritesState: [String: Bool] {
        guard let data = favoritesStateJsonStr.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    // MARK: - Helper method to update favoritesStateJson directly
    private func updateFavoritesState(for itemName: String, value: Bool) {
        var state = favoritesState
        state[itemName] = value
        if let data = try? JSONEncoder().encode(state),
            let jsonString = String(data: data, encoding: .utf8)
        {
            favoritesStateJsonStr = jsonString
        }
    }

    // MARK: -
    var body: some View {
        VStack {
            Text("Favorites").font(.callout)
            List(favoriteItems) { item in
                HStack {
                    Image(systemName: item.iconStr.isEmpty ? "questionmark" : item.iconStr)
                        .renderingMode(.original)
                        .foregroundColor(.blue)
                    Text(item.nameStr)
                }
                .onTapGesture {
                    log.debug("Selected favorite item: \(item.nameStr)")
                }
                .onAppear {
                    if favoritesState[item.nameStr] == nil {
                        updateFavoritesState(for: item.nameStr, value: false)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

