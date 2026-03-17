// ConnectionStatusLamp.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Animated status indicator for remote connections.
//   Green (pulsing) = connected and active
//   Red             = last attempt failed (authFailed / timeout / refused / error)
//   Grey            = not connected / never tried
//
//   IMPORTANT: manager is @Observable — access its properties ONLY inside body/ViewBuilder
//   so SwiftUI's dependency tracking can register the observation. Computed vars outside
//   body are invisible to the tracking system and won't trigger re-renders.

import SwiftUI

// MARK: - ConnectionStatusLamp
struct ConnectionStatusLamp: View {

    let server: RemoteServer
    let manager: RemoteConnectionManager   // @Observable reference — tracked inside body

    @State private var pulse = false

    var body: some View {
        // All manager access inside body — SwiftUI registers the observation here
        let connected = manager.connection(for: server) != nil
        let color: Color = {
            if connected { return .green }
            switch server.lastResult {
            case .authFailed, .timeout, .refused, .error:
                return Color(nsColor: .systemRed)
            default:
                return Color(nsColor: .systemGray).opacity(0.55)
            }
        }()
        let hint: String = {
            if connected { return "Connected" }
            switch server.lastResult {
            case .success:    return "Was connected"
            case .authFailed: return "Auth failed"
            case .timeout:    return "Timed out"
            case .refused:    return "Connection refused"
            case .error:      return "Error: \(server.lastErrorDetail ?? "unknown")"
            case .none:       return "Not connected"
            }
        }()

        return ZStack {
            // Glow ring — pulsing only when connected
            if connected {
                Circle()
                    .fill(color.opacity(pulse ? 0.38 : 0.0))
                    .frame(width: 16, height: 16)
                    .animation(
                        .easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            // Core dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(connected ? 0.55 : 0), radius: 3)
        }
        .onAppear  { pulse = connected }
        .onChange(of: connected) { _, v in withAnimation { pulse = v } }
        .help(hint)
        .animation(.easeInOut(duration: 0.3), value: connected)
    }
}
