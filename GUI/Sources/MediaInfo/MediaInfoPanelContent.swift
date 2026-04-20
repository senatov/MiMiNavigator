//
//  MediaInfoPanelContent.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

struct MediaInfoPanelSection: Identifiable, Equatable {
    let title: String
    let rows: [MediaInfoPanelRow]

    var id: String { title }
}

struct MediaInfoPanelRow: Identifiable, Equatable {
    enum ValueStyle: Equatable {
        case primary
        case path
        case size
        case date
    }

    let label: String
    let value: String
    let valueStyle: ValueStyle

    var id: String { "\(label)|\(value)" }
}

enum MediaInfoPanelTextParser {
    static func parse(_ rawText: String) -> [MediaInfoPanelSection] {
        var sections: [MediaInfoPanelSection] = []
        var currentTitle = "File"
        var currentRows: [MediaInfoPanelRow] = []

        func flush() {
            guard !currentRows.isEmpty else { return }
            sections.append(MediaInfoPanelSection(title: currentTitle, rows: currentRows))
            currentRows = []
        }

        for rawLine in rawText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("---") {
                flush()
                currentTitle = line
                    .replacingOccurrences(of: "-", with: "")
                    .trimmingCharacters(in: .whitespaces)
                continue
            }

            if let separator = line.firstIndex(of: ":") {
                let label = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                currentRows.append(
                    MediaInfoPanelRow(
                        label: label,
                        value: value,
                        valueStyle: valueStyle(for: label)
                    )
                )
            } else {
                currentRows.append(
                    MediaInfoPanelRow(
                        label: "",
                        value: line,
                        valueStyle: .primary
                    )
                )
            }
        }

        flush()
        return sections
    }

    private static func valueStyle(for label: String) -> MediaInfoPanelRow.ValueStyle {
        switch label {
        case "Path", "Folder":
            return .path
        case "Size":
            return .size
        case "Created", "Modified":
            return .date
        default:
            return .primary
        }
    }
}

enum MediaInfoCoordinatesParser {
    static func extract(from text: String) -> (Double, Double)? {
        if let range = text.range(of: "ll=") {
            let tail = text[range.upperBound...]
            let pair = String(tail.split(whereSeparator: { $0 == "\n" || $0 == "&" }).first ?? "")
            let components = pair.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0].trimmingCharacters(in: .whitespaces)),
               let longitude = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                return (latitude, longitude)
            }
        }

        if let range = text.range(of: "GPS:") {
            let line = String(text[range.lowerBound...].split(separator: "\n").first ?? "")
            let numbers = line.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "-" })
            if numbers.count >= 2,
               let latitude = Double(numbers[0].trimmingCharacters(in: .whitespaces)),
               let longitude = Double(numbers[1].trimmingCharacters(in: .whitespaces)) {
                return (latitude, longitude)
            }
        }

        return nil
    }
}
