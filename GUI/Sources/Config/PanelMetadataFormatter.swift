// PanelMetadataFormatter.swift
// MiMiNavigator

import Foundation

// MARK: - Panel Metadata Formatter
@MainActor
enum PanelMetadataFormatter {
    private static var dateFormatters: [String: DateFormatter] = [:]
    // MARK: - Format Size
    static func size(_ bytes: Int64, format: String?, alwaysKB: Bool = false) -> String {
        guard bytes >= 0 else { return "—" }
        if alwaysKB {
            let value = bytes / 1_024 + (bytes % 1_024 == 0 ? 0 : 1)
            return "\(value) KB"
        }
        if bytes == 0 { return "0 B" }
        switch format {
        case "bytes":
            return "\(bytes.formatted()) B"
        case "decimal", "binary":
            let base = format == "decimal" ? 1_000.0 : 1_024.0
            let units = format == "decimal" ? ["B", "KB", "MB", "GB", "TB", "PB"] : ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
            var value = Double(bytes)
            var unit = 0
            while value >= base && unit < units.count - 1 {
                value /= base
                unit += 1
            }
            if unit == 0 { return "\(bytes) B" }
            let number = value.formatted(.number.precision(.fractionLength(0...1)))
            return "\(number) \(units[unit])"
        default:
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    // MARK: - Format Date
    static func date(_ date: Date?, format: String) -> String {
        guard let date else { return "" }
        if let formatter = dateFormatters[format] { return formatter.string(from: date) }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        switch format {
        case "short": formatter.dateFormat = "dd.MM.yy HH:mm"
        case "long": formatter.dateFormat = "dd.MM.yyyy HH:mm"
        case "medium":
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        case "relative":
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
        case "iso":
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        default:
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        dateFormatters[format] = formatter
        return formatter.string(from: date)
    }
}
