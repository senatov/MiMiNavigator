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

    /// Convert URL to canonical URL (resolved symlinks, standardized)
    static func canonical(_ url: URL) -> URL {
        if isRemoteURL(url) {
            return url.standardized
        }
        return url.standardized.resolvingSymlinksInPath()
    }

    /// Convert URL to canonical path string
    static func canonicalPath(_ url: URL) -> String {
        isRemoteURL(url) ? canonical(url).absoluteString : canonical(url).path
    }

    /// Convert string path to canonical form
    static func canonical(from path: String) -> String {
        if let url = URL(string: path), isRemoteURL(url) {
            return url.standardized.absoluteString
        } else if let url = URL(string: path), url.isFileURL {
            return url.standardized.resolvingSymlinksInPath().path
        } else {
            return (path as NSString).standardizingPath
        }
    }

    /// Convert string path to canonical URL
    static func canonicalURL(from path: String) -> URL {
        if let url = URL(string: path), isRemoteURL(url) {
            return url.standardized
        }
        return URL(fileURLWithPath: canonical(from: path)).standardizedFileURL
    }

    /// Check if two paths point to the same location
    static func areEqual(_ path1: String, _ path2: String) -> Bool {
        canonical(from: path1) == canonical(from: path2)
    }

    /// Check if two URLs point to the same location
    static func areEqual(_ url1: URL, _ url2: URL) -> Bool {
        canonical(url1) == canonical(url2)
    }

    /// Check whether URL belongs to a remote file provider.
    static func isRemoteURL(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
            case "sftp", "ftp": return true
            default: return false
        }
    }
}
