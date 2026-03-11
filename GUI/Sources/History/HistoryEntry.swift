    // HistoryEntry.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 28.09.2024.
    // Moved: 13.02.2026 — from Primitives to States/History
    // Copyright © 2024-2026 Senatov. All rights reserved.

    import Foundation

    // MARK: - History entry for navigation tracking
    struct HistoryEntry: Codable, Equatable {
        var url: URL
        var timestamp: Date
        var status: HistoryStatus
        var snapshot: FileSnapshot?

        // MARK: - Equatable
        static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
            lhs.url == rhs.url
        }

        // MARK: - Coding

        enum CodingKeys: String, CodingKey {
            case url
            case path     // legacy key (v2)
            case timestamp
            case status
            case snapshot
        }

        init(url: URL, timestamp: Date, status: HistoryStatus, snapshot: FileSnapshot?) {
            self.url = url.standardizedFileURL
            self.timestamp = timestamp
            self.status = status
            self.snapshot = snapshot
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Prefer new URL field
            if let url = try container.decodeIfPresent(URL.self, forKey: .url) {
                self.url = url.standardizedFileURL
            }
            // Fallback for old persisted data (v2: stored "path")
            else if let path = try container.decodeIfPresent(String.self, forKey: .path) {
                self.url = URL(fileURLWithPath: path).standardizedFileURL
            }
            else {
                throw DecodingError.dataCorruptedError(
                    forKey: .url,
                    in: container,
                    debugDescription: "HistoryEntry missing both 'url' and legacy 'path'"
                )
            }

            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
            self.status = try container.decode(HistoryStatus.self, forKey: .status)
            self.snapshot = try container.decodeIfPresent(FileSnapshot.self, forKey: .snapshot)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(url, forKey: .url)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(snapshot, forKey: .snapshot)
        }
    }
