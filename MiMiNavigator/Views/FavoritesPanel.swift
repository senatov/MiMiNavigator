// FavoritesPanel.swift
// MiMiNavigator

//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

// Description: Enhanced to include Finder-style items and JSON-based state persistence

import SwiftUI
import SwiftyBeaver

// MARK: - FavoritesPanel

/// A sidebar panel displaying user's favorite locations in a Finder-style interface.
struct FavoritesPanel: View {
    // MARK: - Favorite Item Model

    @AppStorage("favoritesState") private var favoritesStateJson: String = "" // JSON storage for favorites state

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
        guard let data = favoritesStateJson.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    // MARK: - Helper method to update favoritesStateJson directly

    private func updateFavoritesState(for itemName: String, value: Bool) {
        var state = favoritesState
        state[itemName] = value
        if let data = try? JSONEncoder().encode(state),
           let jsonString = String(data: data, encoding: .utf8) {
            favoritesStateJson = jsonString
        }
    }

    // Public method to access favoriteItems
    func getFavoriteItems() -> [FavoriteItem] {
        return favoriteItems
    }

    var body: some View {
        VStack {
            Text("Favorites").font(.callout)
            List(favoriteItems) { item in
                HStack {
                    Image(systemName: item.icon.isEmpty ? "questionmark" : item.icon) // Default icon if icon name is empty
                        .foregroundColor(.blue)
                    Text(item.name)
                }
                .onTapGesture {
                    LogMan.log.debug("Selected favorite item: \(item.name)")
                }
                .onAppear {
                    if favoritesState[item.name] == nil {
                        updateFavoritesState(for: item.name, value: false)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview
struct FavoritesPanel_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesPanel()
    }
}

