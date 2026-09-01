// ThumbnailAspectRatioReader.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.09.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reads image dimensions without decoding the full file.

import Foundation
import ImageIO

// MARK: - ThumbnailAspectRatioReader

enum ThumbnailAspectRatioReader {
    // MARK: - Column Span

    nonisolated static func columnSpan(for url: URL) -> Int? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0,
              height > 0 else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let ratio = (5...8).contains(orientation) ? height / width : width / height
        if ratio > 2.25 { return 3 }
        if ratio > 1.25 { return 2 }
        return 1
    }
}
