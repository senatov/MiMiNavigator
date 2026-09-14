import AppKit
import FindFilesKit

// MARK: - Results Content Measurement
@MainActor
enum FindFilesResultsSizing {
    // MARK: - Measure Columns
    static func measure(_ results: [FindFilesResult]) -> [String: CGFloat] {
        let sample = Array(results.prefix(1000))
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let date = DateFormatter()
        date.dateFormat = "dd.MM.yyyy HH:mm"
        return [
            "#": width([String(results.count)], minimum: 32, maximum: 65),
            "Name": width(sample.map(\.fileName), minimum: 140, maximum: 650, name: true) + 24,
            "Location": width(sample.map { ($0.filePath as NSString).deletingLastPathComponent }, minimum: 160, maximum: 650),
            "Date Mod.": width(sample.map { $0.modifiedDate.map(date.string(from:)) ?? "-" }, minimum: 145, maximum: 180),
            "Size": width(sample.map { formatter.string(fromByteCount: $0.fileSize) }, minimum: 70, maximum: 120),
            "Match": width(sample.map { $0.matchContext ?? "-" }, minimum: 60, maximum: 240)
        ]
    }
    // MARK: - Measure Text
    private static func width(_ strings: [String], minimum: CGFloat, maximum: CGFloat, name: Bool = false) -> CGFloat {
        let font = name ? NSFont.systemFont(ofSize: 14, weight: .light) : NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let widths = strings.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.sorted()
        guard !widths.isEmpty else { return minimum }
        let measured = widths[min(widths.count - 1, Int(Double(widths.count) * 0.95))]
        return min(maximum, max(minimum, ceil(measured) + 22))
    }
}

// MARK: - Results Column Fitting
@MainActor
enum FindFilesResultsColumnFit {
    // MARK: - Fit Visible Columns
    static func apply(to table: NSTableView, widths: [String: CGFloat]) {
        let columns = table.tableColumns.filter { !$0.isHidden }
        guard !columns.isEmpty else { return }
        table.columnAutoresizingStyle = .noColumnAutoresizing
        let available = table.enclosingScrollView?.contentSize.width ?? table.bounds.width
        let fixed = columns.filter { $0.title != "Name" && $0.title != "Location" }
        let flexible = columns.filter { $0.title == "Name" || $0.title == "Location" }
        let fixedWidth = fixed.reduce(CGFloat.zero) { $0 + (widths[$1.title] ?? 80) }
        let wanted = flexible.reduce(CGFloat.zero) { $0 + (widths[$1.title] ?? 200) }
        let remaining = max(CGFloat(flexible.count) * 100, available - fixedWidth - CGFloat(columns.count) * table.intercellSpacing.width - 4)
        for column in columns {
            let natural = widths[column.title] ?? 80
            let value = flexible.contains(column) ? max(100, remaining * natural / max(1, wanted)) : natural
            column.width = min(column.maxWidth, max(column.minWidth, value))
        }
    }
}
