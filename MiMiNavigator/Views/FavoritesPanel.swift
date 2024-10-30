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

    // Initialize logger
    let log = SwiftyBeaver.self
    struct FavoriteItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String // SF Symbols icon name for simplicity
    }

    @AppStorage("favoritesState") private var favoritesStateJson: String = "" // JSON storage for favorites state

    // Convert JSON string to a dictionary for accessing favorites state
    private var favoritesState: [String: Bool] {
        guard let data = favoritesStateJson.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    // Helper method to update favoritesStateJson directly
    private func updateFavoritesState(for itemName: String, value: Bool) {
        var state = favoritesState
        state[itemName] = value
        if let data = try? JSONEncoder().encode(state),
           let jsonString = String(data: data, encoding: .utf8) {
            favoritesStateJson = jsonString
        }
    }

    // Define Finder-style favorite items
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

    // Public method to access favoriteItems
    func getFavoriteItems() -> [FavoriteItem] {
        return favoriteItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Favorites")
                .font(.headline)
                .padding(.top)
                .padding(.leading)

            List(favoriteItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                    Text(item.name)
                }
                .onTapGesture {
                    // Log selected favorite item
                    log.debug("Selected favorite item: \(item.name)")
                }
                .onAppear {
                    // Initialize item state if missing by updating JSON directly
                    if favoritesState[item.name] == nil {
                        updateFavoritesState(for: item.name, value: false)
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .padding()
    }
}

// MARK: - Preview

struct FavoritesPanel_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesPanel()
            .previewLayout(.sizeThatFits)
    }
}
