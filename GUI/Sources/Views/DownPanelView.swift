    //
    //  DownPanelView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 28.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

    //
    //  DownPanelView.swift
    //  mimi_project
    //
    //  Created automatically from PanelsRowView extraction
    //

import SwiftUI

    /// Bottom command toolbar similar to Total Commander.
    /// Provides buttons for quick file operations: View, Edit, Copy, Move, Delete, New Folder, and Properties.
struct DownPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                DownToolbarButtonView(title: "F3 View", systemImage: "eye.circle") {
                    log.debug("View button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.view(file)
                    } else {
                        log.debug("No file selected for View")
                    }
                }
                DownToolbarButtonView(title: "F4 Edit", systemImage: "pencil") {
                    if let file = appState.selectedLeftFile {
                        FActions.edit(file)
                    } else {
                        log.debug("No file selected for Edit")
                    }
                }
                DownToolbarButtonView(title: "F5 Copy", systemImage: "doc.on.doc") {
                    doCopy()
                }
                DownToolbarButtonView(title: "F6 Move", systemImage: "square.and.arrow.down.on.square") {
                    log.debug("Move button tapped")
                }
                DownToolbarButtonView(title: "F7 NewFolder", systemImage: "folder.badge.plus") {
                    log.debug("NewFolder button tapped")
                }
                DownToolbarButtonView(title: "F8 Delete", systemImage: "minus.rectangle") {
                    log.debug("Delete button tapped")
                    if let file = appState.selectedLeftFile {
                        FActions.deleteWithConfirmation(file) {
                            Task {
                                await appState.refreshFiles()
                            }
                        }
                    } else {
                        log.debug("No file selected for Delete")
                    }
                }
                DownToolbarButtonView(title: "Settings", systemImage: "gearshape") {
                    log.debug("Settings button tapped")
                }
                DownToolbarButtonView(title: "Console", systemImage: "terminal") {
                    log.debug("Console button tapped")
                    openConsoleInDirectory("~")
                }
                DownToolbarButtonView(title: "Exit", systemImage: "power") {
                    log.debug("F4 Exit button tapped")
                    exitApp()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.07)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // Subtle bevel highlight (keeps main colors intact)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                // Ambient soft shadow close to the surface
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                // Main drop shadow per macOS 26.1 liquid glass
                    .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 12)
                // Optional subtle top highlight glow
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.6)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.07)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
        // MARK: -
    func doPanelToggled(_ event: NSEvent) -> NSEvent? {
        log.debug(#function)
        appState.toggleFocus()
        appState.forceFocusSelection()
        if event.modifierFlags.contains(.shift) {
            log.debug("Shift+Tab pressed → toggle focused panel (reverse)")
        } else {
            log.debug("Tab pressed → toggle focused panel")
        }
        return nil
    }
    
        // MARK: - Toolbar
    func doCopy() {
            // Determine source file based on focused panel (deprecated API removed)
        let sourceFile = (appState.focusedPanel == .left) ? appState.selectedLeftFile : appState.selectedRightFile
        
            // Determine target side explicitly to avoid 'opposite' ambiguity
        let targetSide: PanelSide = (appState.focusedPanel == .left) ? .right : .left
        
        if let file = sourceFile,
           let targetURL = appState.pathURL(for: targetSide)
        {
           FActions.copy(file, to: targetURL)
           Task {
               await appState.refreshFiles()
           }
        } else {
            log.debug("No source file selected or target URL missing for Copy")
        }
    }
    
        // MARK: -
    func exitApp() {
        log.debug(#function)
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
}
