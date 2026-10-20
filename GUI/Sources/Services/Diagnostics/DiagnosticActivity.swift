import Foundation

// MARK: - Diagnostic Activity
/// A bounded snapshot of work in progress for main-queue delay reports.
final class DiagnosticActivity: @unchecked Sendable {
    static let shared = DiagnosticActivity()
    private let lock = NSLock()
    private var active: [UUID: (name: String, started: Date)] = [:]
    private var recent: [String] = []
    private let recentLimit = 8

    private init() {}

    // MARK: - Begin
    func begin(_ name: String) -> UUID {
        let id = UUID()
        lock.lock()
        active[id] = (name, .now)
        lock.unlock()
        return id
    }

    // MARK: - End
    func end(_ id: UUID, outcome: String) {
        lock.lock()
        if let entry = active.removeValue(forKey: id) {
            let duration = String(format: "%.3f", Date().timeIntervalSince(entry.started))
            recent.append("\(entry.name):\(outcome):\(duration)s")
            if recent.count > recentLimit { recent.removeFirst(recent.count - recentLimit) }
        }
        lock.unlock()
    }

    // MARK: - Snapshot
    func snapshot() -> String {
        lock.lock()
        let activeCount = active.count
        let oldest = Array(active.values.sorted { $0.started < $1.started }.prefix(8))
        let completed = Array(recent.suffix(4))
        lock.unlock()
        let now = Date()
        let running = oldest
            .map { "\($0.name):\(String(format: "%.1f", now.timeIntervalSince($0.started)))s" }
        return "activeCount=\(activeCount) active=[\(running.joined(separator: ","))] recent=[\(completed.joined(separator: ","))]"
    }
}
