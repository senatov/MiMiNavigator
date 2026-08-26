// FileOperationOutcomePresenter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Consistent completion, cancellation, and failure feedback for file operations.

import AppKit
import Foundation

// MARK: - File Operation Outcome Presenter
@MainActor
enum FileOperationOutcomePresenter {
    enum Operation {
        case copy
        case move
        case delete
        case rename
        case pack
        case shareLink
        var completedVerb: String {
            switch self {
            case .copy: return "Copied"
            case .move: return "Moved"
            case .delete: return "Moved to Trash"
            case .rename: return "Renamed"
            case .pack: return "Created"
            case .shareLink: return "Share+Link ready"
            }
        }
        var failureTitle: String {
            switch self {
            case .copy: return "Copy Failed"
            case .move: return "Move Failed"
            case .delete: return "Move to Trash Failed"
            case .rename: return "Rename Failed"
            case .pack: return "Archive Creation Failed"
            case .shareLink: return "Share+Link Failed"
            }
        }
        var actionTitle: String {
            switch self {
            case .copy: return "Copy"
            case .move: return "Move"
            case .delete: return "Move to Trash"
            case .rename: return "Rename"
            case .pack: return "Archive creation"
            case .shareLink: return "Share+Link"
            }
        }
        var icon: String {
            switch self {
            case .copy: return "doc.on.doc.fill"
            case .move: return "folder.fill.badge.arrow.forward"
            case .delete: return "trash.fill"
            case .rename: return "pencil.line"
            case .pack: return "archivebox.fill"
            case .shareLink: return "link.badge.plus"
            }
        }
    }

    // MARK: - Success
    static func success(
        _ operation: Operation,
        itemCount: Int = 1,
        resultURL: URL? = nil,
        displayName: String? = nil,
        sourceURLs: [URL] = []
    ) {
        let object = displayName ?? countDescription(itemCount)
        InAppNoticeCenter.shared.showToast(
            "\(operation.completedVerb) \(object)",
            message: operationDetails(sourceURLs: sourceURLs, resultURL: resultURL),
            systemImage: operation.icon,
            tint: .green,
            actionTitle: resultURL == nil ? nil : "Open Result",
            action: openAction(for: resultURL)
        )
    }

    // MARK: - Failure
    static func failure(_ operation: Operation, error: Error, retry: (() -> Void)? = nil) {
        failure(operation, message: error.localizedDescription, retry: retry)
    }

    static func failure(_ operation: Operation, message: String, retry: (() -> Void)? = nil) {
        InAppNoticeCenter.shared.showBanner(
            title: operation.failureTitle,
            message: message,
            systemImage: "xmark.octagon.fill",
            tint: .red,
            actionTitle: retry == nil ? nil : "Retry",
            action: retry
        )
    }

    // MARK: - Cancelled
    static func cancelled(_ operation: Operation) {
        InAppNoticeCenter.shared.showToast(
            "\(operation.actionTitle) cancelled",
            systemImage: "stop.circle.fill",
            tint: .secondary
        )
    }

    private static func countDescription(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    private static func operationDetails(sourceURLs: [URL], resultURL: URL?) -> String? {
        var details: [String] = []
        if let first = sourceURLs.first {
            let suffix = sourceURLs.count > 1 ? " (+\(sourceURLs.count - 1) more)" : ""
            details.append("From: \(first.path)\(suffix)")
        }
        if let resultURL {
            details.append("To: \(resultURL.isFileURL ? resultURL.path : resultURL.absoluteString)")
        }
        return details.isEmpty ? nil : details.joined(separator: "\n")
    }

    private static func openAction(for url: URL?) -> (() -> Void)? {
        guard let url else { return nil }
        return {
            if url.isFileURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
