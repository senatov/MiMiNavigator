// BatchOperationType.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Operation type labels used by batch confirmation dialogs.

import Foundation

// MARK: - Batch Operation Type
enum BatchOperationType: String, Sendable {
    case copy = "Copying"
    case move = "Moving"
    case delete = "Deleting"
    case pack = "Packing"

    var localizedTitle: String {
        switch self {
        case .copy: return L10n.BatchOperation.copying
        case .move: return L10n.BatchOperation.moving
        case .delete: return L10n.BatchOperation.deleting
        case .pack: return L10n.BatchOperation.packing
        }
    }

    var pastTense: String {
        switch self {
        case .copy: return L10n.BatchOperation.copied
        case .move: return L10n.BatchOperation.moved
        case .delete: return L10n.BatchOperation.deleted
        case .pack: return L10n.BatchOperation.packed
        }
    }
}
