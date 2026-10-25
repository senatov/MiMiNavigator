import Foundation

// MARK: - Panel History Snapshot
struct PanelHistorySnapshot: Codable, Equatable {
    let sortKey: String
    let sortAscending: Bool
    let selectedPath: String?
    let viewMode: PanelViewMode
}
