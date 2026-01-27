// PathUtils.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Utility functions for path normalization and comparison

import Foundation

// MARK: - Path Utilities
/// Common path manipulation functions
enum PathUtils {
    
    /// Convert URL to canonical path (resolved symlinks, standardized)
    static func canonical(_ url: URL) -> String {
        url.standardized.resolvingSymlinksInPath().path
    }
    
    /// Convert string path to canonical form
    static func canonical(from path: String) -> String {
        if let url = URL(string: path), url.isFileURL {
            return url.standardized.resolvingSymlinksInPath().path
        } else {
            return (path as NSString).standardizingPath
        }
    }
    
    /// Check if two paths point to the same location
    static func areEqual(_ path1: String, _ path2: String) -> Bool {
        canonical(from: path1) == canonical(from: path2)
    }
}
