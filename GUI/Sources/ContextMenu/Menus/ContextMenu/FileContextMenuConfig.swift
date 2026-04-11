//
//  FileContextMenuConfig.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 31.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import UniformTypeIdentifiers

enum FileContextMenuConfig {
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "3gp",
    ]

    static let audioExtensions: Set<String> = [
        "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma", "aiff",
    ]

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp", "ico",
    ]

    static let mediaConformingTypes: [UTType] = [.image, .movie, .audio]

    static func isKnownMediaExtension(_ ext: String) -> Bool {
        let normalized = ext.lowercased()
        return videoExtensions.contains(normalized)
            || audioExtensions.contains(normalized)
            || imageExtensions.contains(normalized)
    }
}
