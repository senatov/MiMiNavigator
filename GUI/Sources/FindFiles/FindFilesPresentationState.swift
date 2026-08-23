// FindFilesPresentationState.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: UI-only selection, tab, error, and archive-password presentation state.

import FindFilesKit

// MARK: - Find Files Presentation State
struct FindFilesPresentationState {
    var activeModule: FindFilesTab = .general
    var selectedResult: FindFilesResult?
    var selectedResultIDs: Set<FindFilesResult.ID> = []
    var errorMessage: String?
    var showPasswordDialog = false
    var passwordArchiveName = ""
    var archivePassword = ""
}
