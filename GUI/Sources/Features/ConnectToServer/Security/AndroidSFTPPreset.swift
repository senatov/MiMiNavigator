import SwiftUI

// MARK: - Android SFTP Preset
struct AndroidSFTPPreset: View {
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onSelect) {
                Label("New Android SFTP Profile · Alpha / Experimental", systemImage: "smartphone")
            }
            if isActive {
                Text("Start an SFTP server on Android. Enter its Wi-Fi address, port and credentials below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
