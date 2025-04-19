//
//  ButtonNavOnBreadCamp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 19.04.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

struct ButtonNavOnBreadCamp: View {
    @State private var showFavTreePopup = false
    @State private var favTreeStruct: [CustomFile] = []
    @State private var selectedFile: CustomFile? = nil
    let lineLimit = 250

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                log.debug("Back: navigating to previous directory")
            }) {
                Image(systemName: "arrowshape.backward")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)

            Button(action: {
                log.debug("Forward: navigating to next directory")
            }) {
                Image(systemName: "arrowshape.right")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
            .disabled(true)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    log.debug("Navigation between favorites")
                    showFavTreePopup = true
                }
            }) {
                Image(systemName: "menucard")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
            .help("Go up to directory Menu")
            .buttonStyle(.plain)
            .sheet(isPresented: $showFavTreePopup) {
                buildFavTreeMenu()
            }
        }
    }

    // MARK: -
    func buildFavTreeMenu() -> some View {
        log.debug("builFavTreeMenu()")
        return TreeView(files: $favTreeStruct, selectedFile: $selectedFile)
            .padding(6)
            .frame(maxWidth: CGFloat(lineLimit))
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)))
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3), value: favTreeStruct)
            .onAppear {
                Task(priority: .background) {
                    await fetchFavTree()
                }
            }
    }


    @MainActor
    private func fetchFavTree() async {
        log.debug("fetchFavTree()")
        let favScanner = FavScanner()
        favTreeStruct = favScanner.scanFavorites()
    }

}
