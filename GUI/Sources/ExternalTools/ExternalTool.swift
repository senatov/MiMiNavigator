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
    let installCommand: String?
    let purpose: String
    let isSystemTool: Bool

    init(
        id: String,
        name: String,
        binaryCandidates: [String],
        brewFormula: String?,
        websiteURL: String?,
        installCommand: String? = nil,
        purpose: String,
        isSystemTool: Bool
    ) {
        self.id = id
        self.name = name
        self.binaryCandidates = binaryCandidates
        self.brewFormula = brewFormula
        self.websiteURL = websiteURL
        self.installCommand = installCommand
        self.purpose = purpose
        self.isSystemTool = isSystemTool
    }

    // MARK: - Resolved path (first existing candidate)

    var resolvedPath: String? {
        binaryCandidates.first { FileManager.default.fileExists(atPath: $0) }
    }


    var isInstalled: Bool { resolvedPath != nil }


    var installHint: String {
        if let installCommand {
            return installCommand
        }
        if let formula = brewFormula {
            return "brew install \(formula)"
        }
        if let url = websiteURL {
            return "Download from: \(url)"
        }
        return "Install manually"
    }
}
