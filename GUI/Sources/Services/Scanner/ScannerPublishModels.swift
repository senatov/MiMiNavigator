// ScannerPublishModels.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Immutable comparison models used when publishing directory scans.

import FileModelKit
import Foundation

// MARK: - Scanner Publish State
struct ScannerPublishState {
    let samePath: Bool
    let sameHash: Bool
    let sameVisibleCount: Bool
    let currentDisplayedCount: Int
}

// MARK: - File Publish Fingerprint
struct FilePublishFingerprint: Equatable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let isParentEntry: Bool
    let sizeVersion: Int
    let childCount: Int?
    let directorySize: Int64?
    let shallowSize: Int64?
    let sizeInBytes: Int64
    let sizeIsExact: Bool
    let modifiedTimestamp: TimeInterval?
    let creationTimestamp: TimeInterval?
    let lastOpenedTimestamp: TimeInterval?
    let dateAddedTimestamp: TimeInterval?
    let fileExtension: String
    let permissions: Int16
    let owner: String
    let group: String
    let isAlias: Bool
    let isSymbolicLink: Bool
    let isOSHidden: Bool
    let securityState: String

    // MARK: - Init
    init(file: CustomFile) {
        id = file.id
        name = file.nameStr
        path = file.pathStr
        isDirectory = file.isDirectory
        isParentEntry = file.isParentEntry
        sizeVersion = file.sizeVersion
        childCount = file.cachedChildCount
        directorySize = file.cachedDirectorySize
        shallowSize = file.cachedShallowSize
        sizeInBytes = file.sizeInBytes
        sizeIsExact = file.sizeIsExact
        modifiedTimestamp = file.modifiedDate?.timeIntervalSince1970
        creationTimestamp = file.creationDate?.timeIntervalSince1970
        lastOpenedTimestamp = file.lastOpenedDate?.timeIntervalSince1970
        dateAddedTimestamp = file.dateAdded?.timeIntervalSince1970
        fileExtension = file.fileExtension
        permissions = file.posixPermissions
        owner = file.ownerName
        group = file.groupName
        isAlias = file.isAlias
        isSymbolicLink = file.isSymbolicLink
        isOSHidden = file.isOSHidden
        securityState = String(describing: file.securityState)
    }
}
