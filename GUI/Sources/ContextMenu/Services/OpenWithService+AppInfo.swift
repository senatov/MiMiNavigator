// OpenWithService+AppInfo.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppInfo descriptor construction and caching.

import AppKit
import Foundation

// MARK: - Open With App Info
extension OpenWithService {
    // MARK: - Resolve Current Application
    func resolvedApplicationURL(bundleIdentifier: String, fallbackURL: URL?) -> URL? {
        let registeredURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
        for candidate in [registeredURL, fallbackURL].compactMap({ $0 }) {
            let normalizedURL = candidate.standardizedFileURL
            guard fileManager.fileExists(atPath: normalizedURL.path) else { continue }
            guard Bundle(url: normalizedURL)?.bundleIdentifier == bundleIdentifier else { continue }
            return normalizedURL
        }
        return nil
    }

    func makeAppInfo(from appURL: URL, isDefault: Bool) -> AppInfo? {
        let normalizedURL = appURL.standardizedFileURL
        let cacheKey = normalizedURL.path
        let descriptor: CachedAppDescriptor
        if let cached = Self.appDescriptorCache[cacheKey] {
            descriptor = cached
        } else {
            guard let bundle = Bundle(url: normalizedURL), let bundleIdentifier = bundle.bundleIdentifier else {
                logDebug("makeAppInfo failed path='\(normalizedURL.path)'")
                return nil
            }
            let name = fileManager.displayName(atPath: normalizedURL.path)
            let icon = workspace.icon(forFile: normalizedURL.path)
            icon.size = Constants.appIconSize
            descriptor = CachedAppDescriptor(bundleIdentifier: bundleIdentifier, name: name, icon: icon, url: normalizedURL)
            Self.appDescriptorCache[cacheKey] = descriptor
        }
        logDebug("app='\(descriptor.name)'")
        logDebug("bundle='\(descriptor.bundleIdentifier)' default=\(isDefault)")
        logDebug("path='\(descriptor.url.path)'")
        return AppInfo(
            id: descriptor.bundleIdentifier,
            name: descriptor.name,
            bundleIdentifier: descriptor.bundleIdentifier,
            icon: descriptor.icon,
            url: descriptor.url,
            isDefault: isDefault
        )
    }
}
