//
//  BreadCrumbView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

/// Breadcrumb trail UI component for representing navigation path
struct BreadCrumbView: View {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide

    init(selectedSide: PanelSide) {
        log.info("BreadCrumbView init" + " for side \(selectedSide)")
        self.panelSide = selectedSide
    }


    // MARK: -
    var body: some View {
        log.info(#function + " for side \(panelSide)")
        return HStack(spacing: 4) {
            ForEach(pathComponents.indices, id: \.self) { index in
                breadcrumbItem(index: index)
            }
        }
    }


    // MARK: -
    private var pathComponents: [String] {
        log.info(#function + " for side \(panelSide)")
        let path = (panelSide == .left ? appState.leftPath : appState.rightPath)
        return path.split(separator: "/").map(String.init)
    }


    // MARK: - Breadcrumb Item
    @ViewBuilder
    private func breadcrumbItem(index: Int) -> some View {

        if index > 0 {
            Image(systemName: "chevron.forward")
                .foregroundColor(.secondary)
        }

        Button(action: {
            handlePathSelection(upTo: index)
        }) {
            Text(pathComponents[index])
                .font(.callout)
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .help("Navigate to \(pathComponents[index])")
    }

    // MARK: - Handle Selection
    private func handlePathSelection(upTo index: Int) {
        log.info(#function + " for index \(index) on side \(panelSide)")
        let newPath = "/" + pathComponents.prefix(index + 1).joined(separator: "/")
        appState.focusedSide = panelSide
        appState.updatePath(newPath, on: appState.focusedSide)
        Task {
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: newPath)
                await appState.refreshLeftFiles()
            }
            else {
                await appState.scanner.setRightDirectory(pathStr: newPath)
                await appState.refreshRightFiles()
            }
        }
    }
}
