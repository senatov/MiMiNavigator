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
        sourceURLs: [URL] = [],
        undo: UndoOperation? = nil
    ) {
        let object = displayName ?? countDescription(itemCount)
        InAppNoticeCenter.shared.showToast(
            "\(operation.completedVerb) \(object)",
            message: operationDetails(operation: operation, sourceURLs: sourceURLs, resultURL: resultURL),
            systemImage: operation.icon,
            tint: .green,
            actionTitle: undo == nil ? (resultURL == nil ? nil : "Open Result") : "UNDO",
            isActionAvailable: undo?.isAvailable,
            action: undo?.action ?? openAction(for: resultURL)
        )
    }

    // MARK: - Undo Operation
    struct UndoOperation {
        let isAvailable: () -> Bool
        let action: () -> Void
    }

    static func moveUndo(from currentURLs: [URL], to originalURLs: [URL], refresh: @escaping () -> Void) -> UndoOperation? {
        guard currentURLs.count == originalURLs.count, !currentURLs.isEmpty else { return nil }
        return UndoOperation(
            isAvailable: {
                zip(currentURLs, originalURLs).allSatisfy {
                    FileManager.default.fileExists(atPath: $0.0.path) && !FileManager.default.fileExists(atPath: $0.1.path)
                }
            },
            action: {
                do {
                    for (current, original) in zip(currentURLs, originalURLs) {
                        try FileManager.default.moveItem(at: current, to: original)
                    }
                    refresh()
                    log.info("[FileOps] undo restored \(currentURLs.count) item(s)")
                } catch {
                    log.error("[FileOps] undo failed: \(error.localizedDescription)")
                    InAppNoticeCenter.shared.showError(title: "Undo Failed", message: error.localizedDescription)
                }
            }
        )
    }

    static func copyUndo(copiedURLs: [URL], refresh: @escaping () -> Void) -> UndoOperation? {
        guard !copiedURLs.isEmpty else { return nil }
        return UndoOperation(
            isAvailable: {
                copiedURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
            },
            action: {
                do {
                    for copiedURL in copiedURLs {
                        try FileManager.default.trashItem(at: copiedURL, resultingItemURL: nil)
                    }
                    refresh()
                    log.info("[FileOps] undo removed \(copiedURLs.count) copied item(s)")
                } catch {
                    log.error("[FileOps] undo failed: \(error.localizedDescription)")
                    InAppNoticeCenter.shared.showError(title: "Undo Failed", message: error.localizedDescription)
                }
            }
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

    private static func operationDetails(operation: Operation, sourceURLs: [URL], resultURL: URL?) -> String? {
        var details: [String] = []
        let sourceLabel: String
        switch operation {
            case .delete: sourceLabel = "Removed"
            default: sourceLabel = "From"
        }
        for sourceURL in sourceURLs {
            details.append("\(sourceLabel): \(sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString)")
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
