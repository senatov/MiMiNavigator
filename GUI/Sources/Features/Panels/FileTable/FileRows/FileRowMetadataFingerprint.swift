// FileRowMetadataFingerprint.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.07.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visible file metadata identity used by row diffing.

import FileModelKit
import Foundation

// MARK: - File Row Metadata Fingerprint
struct FileRowMetadataFingerprint: Hashable {
    let creationTimestamp: TimeInterval?
    let lastOpenedTimestamp: TimeInterval?
    let dateAddedTimestamp: TimeInterval?
    let permissions: Int16
    let owner: String
    let group: String
    let fileExtension: String
    let isAlias: Bool
    let isSymbolicLink: Bool
    let isOSHidden: Bool

    // MARK: - Init
    init(file: CustomFile) {
        creationTimestamp = file.creationDate?.timeIntervalSince1970
        lastOpenedTimestamp = file.lastOpenedDate?.timeIntervalSince1970
        dateAddedTimestamp = file.dateAdded?.timeIntervalSince1970
        permissions = file.posixPermissions
        owner = file.ownerName
        group = file.groupName
        fileExtension = file.fileExtension
        isAlias = file.isAlias
        isSymbolicLink = file.isSymbolicLink
        isOSHidden = file.isOSHidden
    }
}
