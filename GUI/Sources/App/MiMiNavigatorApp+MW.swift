//
//  MiMiNavigatorApp+MainWindow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 05.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

extension MiMiNavigatorApp {
    // MARK: -
    var body: some Scene {
        WindowGroup {
            mainWindowContent
        }
        .defaultSize(width: 1200, height: 700)
        .defaultPosition(.center)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(appState: appState)
            SettingsCommands()
        }
    }

    // MARK: - Main Window Content
    var mainWindowContent: some View {
        log.debug(#function)
        return DuoFilePanelView()
            .environment(appState)
            .environment(dragDropManager)
            .contextMenuDialogs(coordinator: contextMenuCoordinator, appState: appState)
            .navigationTitle("MiMiNavigator V \(Self.appVersion)")
            .onAppear {
                handleMainWindowAppear()
            }
            .onChange(of: scenePhase) {
                handleScenePhaseChange()
            }
            .toolbar {
                appToolbarContent
            }
            .glassEffect(Glass.identity)
            .sheet(
                isPresented: Binding(
                    get: { dragDropManager.showConfirmationDialog },
                    set: { dragDropManager.showConfirmationDialog = $0 }
                )
            ) {
                if let operation = dragDropManager.pendingOperation {
                    transferConfirmationDialog(for: operation)
                }
            }
            .overlay {
                batchProgressOverlay
            }
    }
}
