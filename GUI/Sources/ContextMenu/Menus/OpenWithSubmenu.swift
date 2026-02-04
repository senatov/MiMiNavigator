// OpenWithSubmenu.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Refactored: 04.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Submenu for "Open With" action - shows available applications

import SwiftUI

/// Submenu showing applications that can open the selected file
/// Note: SwiftUI Menu content is evaluated lazily, so we pre-fetch apps
struct OpenWithSubmenu: View {
    let file: CustomFile
    
    init(file: CustomFile) {
        self.file = file
        log.debug("\(#function) → file='\(file.nameStr)' ext=\(file.fileExtension)")
    }
    
    var body: some View {
        Menu {
            // Fetch apps synchronously for immediate display
            let apps = OpenWithService.shared.getApplications(for: file.urlValue)
            
            if apps.isEmpty {
                Text("No applications found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(apps) { app in
                    Button {
                        log.debug("\(#function) selected app='\(app.name)' bundle=\(app.bundleIdentifier) file='\(file.nameStr)'")
                        OpenWithService.shared.openFile(file.urlValue, with: app)
                    } label: {
                        Label {
                            HStack {
                                Text(app.name)
                                if app.isDefault {
                                    Text("(Default)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(nsImage: app.icon)
                        }
                    }
                }
                
                Divider()
            }
            
            // "Other..." button to show system app picker
            Button("Other...") {
                log.debug("\(#function) 'Other...' clicked for file='\(file.nameStr)'")
                OpenWithService.shared.showOpenWithPicker(for: file.urlValue)
            }
            
            Divider()
            
            // "App Store..." to search for apps
            Button("App Store...") {
                log.debug("\(#function) 'App Store...' clicked for ext=\(file.fileExtension)")
                searchAppStore(for: file)
            }
        } label: {
            Label("Open With", systemImage: "arrow.up.right.square")
        }
    }
    
    private func searchAppStore(for file: CustomFile) {
        let ext = file.urlValue.pathExtension
        let searchQuery = ext.isEmpty ? "file opener" : "\(ext) file"
        log.debug("\(#function) searching App Store for query='\(searchQuery)'")
        if let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "macappstore://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Right-click for Open With submenu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        OpenWithSubmenu(file: CustomFile(path: "/Users/senat/test.txt"))
    }
}
