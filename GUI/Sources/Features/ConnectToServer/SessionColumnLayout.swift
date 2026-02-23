// SessionColumnLayout.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column definitions and layout model for Recent Sessions table.
//   Mirrors ColumnID/ColumnSpec/ColumnLayoutModel from FileTable for consistent UX:
//   resizable dividers, sortable headers, persisted widths.

import SwiftUI

// MARK: - Session Column Identity
enum SessionColumnID: String, CaseIterable, Codable, Identifiable {
    case date    = "date"
    case session = "session"
    case status  = "status"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date:    return "Date"
        case .session: return "Session"
        case .status:  return "Status"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .date:    return 90
        case .session: return 0  // flexible
        case .status:  return 70
        }
    }

    var isFlexible: Bool { self == .session }
    var isRequired: Bool { true }

    var alignment: Alignment {
        switch self {
        case .date:    return .leading
        case .session: return .leading
        case .status:  return .center
        }
    }
}

// MARK: - Session Sort Key
enum SessionSortKey: String {
    case date
    case session
    case status
}

// MARK: - Session Column Spec
struct SessionColumnSpec: Codable, Identifiable, Equatable {
    var id: SessionColumnID
    var width: CGFloat
    var isVisible: Bool

    init(id: SessionColumnID, width: CGFloat? = nil) {
        self.id = id
        self.width = width ?? id.defaultWidth
        self.isVisible = true
    }
}

// MARK: - Session Column Layout Model
@MainActor
@Observable
final class SessionColumnLayout {
    var columns: [SessionColumnSpec]
    private let storageKey = "SessionColumnLayout"

    init() {
        self.columns = SessionColumnID.allCases.map { SessionColumnSpec(id: $0) }
        load()
    }

    var fixedColumns: [SessionColumnSpec] {
        columns.filter { !$0.id.isFlexible }
    }

    func setWidth(_ width: CGFloat, for id: SessionColumnID) {
        if let idx = columns.firstIndex(where: { $0.id == id }) {
            columns[idx].width = max(40, min(width, 300))
        }
    }

    func saveWidths() {
        if let data = try? JSONEncoder().encode(columns) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SessionColumnSpec].self, from: data)
        else { return }
        for saved in saved {
            if let idx = columns.firstIndex(where: { $0.id == saved.id }) {
                columns[idx].width = saved.width
            }
        }
    }
}
