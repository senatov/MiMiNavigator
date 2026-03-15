// PanelViewMode.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: View mode enum (list vs thumbnail) for file panels.

import Foundation

// MARK: - PanelViewMode
enum PanelViewMode: String, CaseIterable, Sendable {
    case list      = "list"
    case thumbnail = "thumbnail"
}
