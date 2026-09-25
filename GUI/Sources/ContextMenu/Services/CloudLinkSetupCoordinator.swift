// CloudLinkSetupCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: One-time credential guidance and Share+Link menu availability.

import AppKit
import Foundation

// MARK: - Cloud Link Setup Coordinator
@MainActor
enum CloudLinkSetupCoordinator {
    static let tinyURLSetupURL = URL(string: "https://tinyurl.com/app/dev")!
    private static let googleGuideKey = "cloudLink.setupGuide.googleDriveShown"
    private static let dropboxGuideKey = "cloudLink.setupGuide.dropboxShown"
    private static let tinyURLGuideKey = "cloudLink.setupGuide.tinyURLShown"
    // MARK: - Provider Action Availability
    static func isProviderActionEnabled(_ provider: CloudProvider) -> Bool {
        guard provider == .googleDrive || provider == .dropbox else { return true }
        return hasRequiredCredentials(for: provider)
    }
    static func shouldShowSetupAction(for provider: CloudProvider) -> Bool {
        !hasRequiredCredentials(for: provider) && !guideWasShown(for: provider)
    }
    static func showSetupGuide(for provider: CloudProvider) {
        guard shouldShowSetupAction(for: provider) else { return }
        markGuideShown(for: provider)
        presentProviderGuide(provider)
    }
    static func setupURL(for provider: CloudProvider) -> URL? {
        switch provider {
        case .googleDrive:
            return URL(string: "https://developers.google.com/workspace/guides/create-credentials")
        case .dropbox:
            return URL(string: "https://www.dropbox.com/developers/apps")
        default:
            return nil
        }
    }
    // MARK: - Prepare Share
    static func prepareShare(for provider: CloudProvider) -> Bool {
        guard provider == .googleDrive || provider == .dropbox else { return true }
        guard !hasRequiredCredentials(for: provider) else {
            return prepareTinyURLFallback()
        }
        showSetupGuide(for: provider)
        return false
    }
    // MARK: - Required Credentials
    private static func hasRequiredCredentials(for provider: CloudProvider) -> Bool {
        switch provider {
        case .googleDrive:
            let hasClientSecret = GoogleDriveOAuthConfig.clientSecret?.isEmpty == false
            let hasRefreshToken = (try? GoogleDriveTokenStore.loadRefreshToken())?.isEmpty == false
            return hasClientSecret && hasRefreshToken
        case .dropbox:
            return (try? DropboxTokenStore.loadRefreshToken())?.isEmpty == false
        default:
            return true
        }
    }
    // MARK: - TinyURL Fallback
    private static func prepareTinyURLFallback() -> Bool {
        if (try? TinyURLTokenStore.loadAPIToken())?.isEmpty == false {
            return true
        }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: tinyURLGuideKey) else { return true }
        defaults.set(true, forKey: tinyURLGuideKey)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "TinyURL token is not configured"
        alert.informativeText = "MiMiNavigator can continue and copy the original Google Drive or Dropbox link. To create short mimiNavi links, generate an API token at tinyurl.com/app/dev and save it in Settings → Cloud Share+Link. This guidance is shown only once."
        alert.addButton(withTitle: "Use Long Link")
        alert.addButton(withTitle: "Open Settings")
        if alert.runModal() == .alertSecondButtonReturn {
            SettingsCoordinator.shared.openOnSection(.cloudLink)
            return false
        }
        return true
    }
    // MARK: - Present Provider Guide
    private static func presentProviderGuide(_ provider: CloudProvider) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Set up \(provider.rawValue) Share+Link"
        alert.informativeText = providerInstructions(provider)
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsCoordinator.shared.openOnSection(.cloudLink)
        }
    }
    // MARK: - Provider Instructions
    private static func providerInstructions(_ provider: CloudProvider) -> String {
        switch provider {
        case .googleDrive:
            return "Create Desktop OAuth credentials in Google Cloud Console, enable the Google Drive API, then save the client secret and refresh token in Settings → Cloud Share+Link. Until both values exist, Google Drive sharing remains disabled. This guidance is shown only once."
        case .dropbox:
            return "Create a Dropbox API app with files.metadata.read, sharing.read, and sharing.write permissions, obtain a refresh token, then save it in Settings → Cloud Share+Link. Until the token exists, Dropbox sharing remains disabled. This guidance is shown only once."
        default:
            return "Configure this provider in Settings → Cloud Share+Link."
        }
    }
    // MARK: - Guide State
    private static func guideWasShown(for provider: CloudProvider) -> Bool {
        UserDefaults.standard.bool(forKey: guideKey(for: provider))
    }
    private static func markGuideShown(for provider: CloudProvider) {
        UserDefaults.standard.set(true, forKey: guideKey(for: provider))
    }
    private static func guideKey(for provider: CloudProvider) -> String {
        provider == .googleDrive ? googleGuideKey : dropboxGuideKey
    }
}
