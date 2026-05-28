// FileContextMenu+Visibility.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Section visibility helpers for FileContextMenu.

// MARK: - Visibility

extension FileContextMenu {
    // MARK: - Divider Visibility
    func shouldShowDivider(after section: SectionKind) -> Bool {
        section != .favorites && hasVisibleContent(after: section)
    }

    // MARK: - Remaining Content
    func hasVisibleContent(after section: SectionKind) -> Bool {
        guard let index = sectionOrder.firstIndex(of: section) else {
            return false
        }
        let remainingSections = sectionOrder.dropFirst(index + 1)
        return remainingSections.contains(where: hasVisibleContent(in:))
    }

    // MARK: - Section Content
    func hasVisibleContent(in section: SectionKind) -> Bool {
        switch section {
        case .media:
            return isMediaFile
        case .danger:
            return true
        case .open, .edit, .operations, .navigation, .info:
            return true
        case .favorites:
            return true
        }
    }
}
