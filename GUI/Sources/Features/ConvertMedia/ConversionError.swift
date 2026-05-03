//
//  ConversionError.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import Foundation

// MARK: - ConversionError
enum ConversionError: LocalizedError {
    case toolMissing(String)
    case gifskiMissing
    case gifTooLarge(String)
    case readFailed(String)
    case writeFailed(String)
    case processFailed(Int)
    case unsupportedConversion(String, String)

    var errorDescription: String? {
        switch self {
            case .toolMissing(let tool):
                return "Required tool not found: \(tool). Install via: brew install ffmpeg"
            case .gifskiMissing:
                return "gifski not installed. Install via: brew install gifski"
            case .gifTooLarge(let size):
                return "GIF too large (\(size)) even after downscaling — try shorter video"
            case .readFailed(let name):
                return "Failed to read: \(name)"
            case .writeFailed(let name):
                return "Failed to write: \(name)"
            case .processFailed(let code):
                return "Process exited with code \(code)"
            case .unsupportedConversion(let from, let to):
                return "Conversion \(from) → \(to) is not supported"
        }
    }
}
