// MediaConversionOptions.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Media Conversion Options
struct MediaConversionOptions: Sendable {
    var imageQuality: Double = 0.85
    var preserveImageMetadata = true
    var gifSizeLimitEnabled = true
    var telegramVideoSticker = false
    var telegramStaticSticker = false
    var clipStartSeconds: Double?
    var clipDurationSeconds: Double?
}
