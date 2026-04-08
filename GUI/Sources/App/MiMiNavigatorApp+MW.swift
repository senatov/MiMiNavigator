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
            // MARK: - Environment
            .environment(appState)
            .environment(dragDropManager)

            // MARK: - Navigation & UI
            .navigationTitle("MiMiNavigator V \(Self.appVersion)")
            .toolbar { appToolbarContent }
            .glassEffect(.identity)

            // MARK: - Context Menu
            .contextMenuDialogs(coordinator: contextMenuCoordinator, appState: appState)

            // MARK: - Lifecycle
            .onAppear { handleOnAppear() }
            .onChange(of: scenePhase) { handleScenePhaseChange() }

            // MARK: - Sheets
            .sheet(isPresented: confirmationDialogBinding) {
                if let operation = dragDropManager.pendingOperation {
                    transferConfirmationDialog(for: operation)
                }
            }
            .sheet(isPresented: $showAutomationOnboarding) {
                AutomationPermissionOnboarding(isPresented: $showAutomationOnboarding)
            }

            // MARK: - Overlay
            .overlay { batchProgressOverlay }
    }
    
    // MARK: - Bindings

    private var confirmationDialogBinding: Binding<Bool> {
        Binding(
            get: { dragDropManager.showConfirmationDialog },
            set: { dragDropManager.showConfirmationDialog = $0 }
        )
    }

    // MARK: - Lifecycle Helpers

    private func handleOnAppear() {
        handleMainWindowAppear()

        if AutomationPermissionOnboarding.needsOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showAutomationOnboarding = true
            }
        }
    }
}
