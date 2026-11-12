// MediaInfoConversionOptionsView.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import SwiftUI

// MARK: - Media Info Conversion Options
struct MediaInfoConversionOptionsView: View {
    let sourceFormat: MediaFormat?
    let targetFormat: MediaFormat
    @Binding var imageQuality: Double
    @Binding var preserveImageMetadata: Bool
    @Binding var gifSizeLimitEnabled: Bool
    @Binding var clipStartText: String
    @Binding var clipDurationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sourceFormat?.isImage == true && [.jpg, .heic, .webp].contains(targetFormat) {
                HStack(spacing: 8) {
                    Text("Image quality")
                    Slider(value: $imageQuality, in: 0.1...1, step: 0.05)
                        .accessibilityLabel("Image quality")
                    Text("\(Int((imageQuality * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            if sourceFormat?.isImage == true && [.png, .jpg, .heic, .tiff, .bmp].contains(targetFormat) {
                Toggle("Keep image metadata", isOn: $preserveImageMetadata)
                    .toggleStyle(.checkbox)
            }
            if targetFormat == .gif {
                Toggle("Limit GIF to 19.5 MB", isOn: $gifSizeLimitEnabled)
                    .toggleStyle(.checkbox)
            }
            if sourceFormat?.isVideo == true || sourceFormat == .gif {
                HStack(spacing: 8) {
                    Text("Clip, seconds")
                    TextField("Start", text: $clipStartText)
                        .frame(width: 62)
                        .accessibilityLabel("Clip start in seconds")
                    TextField("Length", text: $clipDurationText)
                        .frame(width: 62)
                        .accessibilityLabel("Clip length in seconds")
                    Text("Leave blank for full length")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.system(size: 12))
    }
}
