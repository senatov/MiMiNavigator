// ExternalTool.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model for external CLI tool — name, paths, brew formula, install hints.

import Foundation


// MARK: - ExternalTool

struct ExternalTool: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let binaryCandidates: [String]
    let brewFormula: String?
    let websiteURL: String?
    let purpose: String
    let isSystemTool: Bool


    // MARK: - Resolved path (first existing candidate)

    var resolvedPath: String? {
        binaryCandidates.first { FileManager.default.fileExists(atPath: $0) }
    }


    var isInstalled: Bool { resolvedPath != nil }


    var installHint: String {
        if let formula = brewFormula {
            return "brew install \(formula)"
        }
        if let url = websiteURL {
            return "Download from: \(url)"
        }
        return "Install manually"
    }
}
