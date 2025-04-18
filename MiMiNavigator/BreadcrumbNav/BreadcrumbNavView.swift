    //
    //  BreadcrumbNavView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 18.04.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI
import SwiftyBeaver


struct BreadcrumbNavView: View {
    let pathComponents: [String]
    let iconForFolder: (String) -> Image

    var body: some View {
        HStack(spacing: 8) {
                // Navigation buttons
            HStack(spacing: 6) {
                Button(action: {
                    log.debug("Back: navigating to previous directory")
                }) {
                    Image(systemName: "chevron.left")
                }

                Button(action: {
                    log.debug("Forward: navigating to next directory")
                }) {
                    Image(systemName: "chevron.right")
                }

                Button(action: {
                    log.debug("Up: navigating to parent directory")
                }) {
                    Image(systemName: "arrow.up")
                }

                Button(action: {
                    log.debug("Refresh: reloading current directory")
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)

                // Path components
            HStack(spacing: 4) {
                ForEach(pathComponents.indices, id: \.self) { index in
                    HStack(spacing: 2) {
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .onTapGesture {
                                    log.debug("Forward: clicked breadcrumb separator")
                                }
                        }

                        Button(action: {
                            log.debug("Clicked path component: \(pathComponents[index])")
                        }) {
                            HStack(spacing: 4) {
                                iconForFolder(pathComponents[index])
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(pathComponents[index])
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )

            Spacer()

                // Right menu
            Menu {
                Button("Properties", action: {
                    log.debug("Properties menu selected")
                })
                Button("Open in Finder", action: {
                    log.debug("Open in Finder menu selected")
                })
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(8)
    }
}

#Preview {
    BreadcrumbNavView(
        pathComponents: ["Users", "senat", "Downloads", "Telegram Desktop"],
        iconForFolder: { name in
            switch name {
                case "Downloads":
                    return Image(systemName: "arrow.down.circle.fill")
                default:
                    return Image(systemName: "folder.fill")
            }
        }
    )
    .frame(height: 36)
    .padding()
}
