//
// FavoritesKitTests.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
//

import Testing
@testable import FavoritesKit

@Suite("FavoritesKit Tests")
struct FavoritesKitTests {
    
    @Test("FavoriteItem creation")
    func testFavoriteItemCreation() {
        let item = FavoriteItem(
            name: "Test",
            path: "/test/path",
            isDirectory: true
        )
        
        #expect(item.name == "Test")
        #expect(item.path == "/test/path")
        #expect(item.isDirectory == true)
    }
    
    @Test("FavoriteItem group creation")
    func testGroupCreation() {
        let child = FavoriteItem(name: "Child", path: "/child")
        let group = FavoriteItem.group(name: "Group", children: [child])
        
        #expect(group.name == "Group")
        #expect(group.path == "")
        #expect(group.children?.count == 1)
    }
    
    @Test("FavPanelSide enum")
    func testPanelSide() {
        let left = FavPanelSide.left
        let right = FavPanelSide.right
        
        #expect(left.rawValue == "left")
        #expect(right.rawValue == "right")
    }
}
