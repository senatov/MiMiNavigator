// InitialToolBootstrapView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.
// Description: First-run progress and retry UI for required command-line tools.

import AppKit
import SwiftUI

// MARK: - Initial Tool Bootstrap View
struct InitialToolBootstrapView: View {
    @Bindable var bootstrap: InitialToolBootstrap
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Set up command-line tools", systemImage: "shippingbox")
                .font(.title2.bold())
            Text("MiMiNavigator is setting up Homebrew and the tools used for Git, archives, media conversion, and SSH connections.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Terminal will show the installation. Allow Terminal automation if macOS asks; installing Homebrew may also require your administrator password.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if bootstrap.isRunning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(bootstrap.statusMessage)
                }
            } else if let error = bootstrap.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if bootstrap.isComplete {
                Label(bootstrap.statusMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            HStack {
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.bordered)
                Spacer()
                if bootstrap.errorMessage != nil {
                    Button("Retry installation") { bootstrap.start() }
                        .buttonStyle(.borderedProminent)
                }
                if bootstrap.isComplete {
                    Button("Continue", action: onComplete)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .interactiveDismissDisabled()
        .task { bootstrap.start() }
        .onChange(of: bootstrap.isComplete) {
            if bootstrap.isComplete { onComplete() }
        }
    }
}
