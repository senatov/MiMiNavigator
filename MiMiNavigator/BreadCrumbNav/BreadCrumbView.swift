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

    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 4) {
            ForEach(pathComponents.indices, id: \.self) { index in
                breadcrumbItem(index: index)
            }
        }
    }


    // MARK: -
    private var pathComponents: [String] {
        log.info(#function)
        let path = (appState.focusedSide == .left ? appState.leftPath : appState.rightPath)
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
    }

    // MARK: - Handle Selection
    private func handlePathSelection(upTo index: Int) {
        log.info(#function)
        let newPath = "/" + pathComponents.prefix(index + 1).joined(separator: "/")
        appState.updatePath(newPath, on: appState.focusedSide)
        Task {
            if appState.focusedSide == .left {
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
