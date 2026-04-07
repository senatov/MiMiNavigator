// RemoteConnectionLampButton.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Clickable lamp button for toolbar dropdown.
//   Green pulsing = connected, grey = idle, red = error.
//   Click toggles connect/disconnect via RemoteConnectionManager.

import SwiftUI


// MARK: - RemoteConnectionLampButton
struct RemoteConnectionLampButton: View {

    let server: RemoteServer
    let onToggle: (RemoteServer) -> Void

    @State private var pulse = false

    private var manager: RemoteConnectionManager { .shared }


    var body: some View {
        let connected = manager.isConnected(to: server)
        let lampColor = resolveLampColor(connected: connected)

        Button {
            onToggle(server)
        } label: {
            ZStack {
                if connected {
                    Circle()
                        .fill(lampColor.opacity(pulse ? 0.45 : 0.0))
                        .frame(width: 14, height: 14)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }
                Circle()
                    .fill(lampColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: lampColor.opacity(connected ? 0.6 : 0), radius: 2)
            }
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .onAppear { pulse = connected }
        .onChange(of: connected) { _, val in withAnimation { pulse = val } }
        .help(connected ? "Disconnect \(server.displayName)" : "Connect \(server.displayName)")
    }



    // MARK: - Lamp Color Logic
    private func resolveLampColor(connected: Bool) -> Color {
        if connected { return .green }
        switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return Color(nsColor: .systemGray).opacity(0.6)
        }
    }
}
