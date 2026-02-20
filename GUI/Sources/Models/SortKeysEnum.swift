// SortKeysEnum.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.08.2025.
// Copyright © 2025 Senatov. All rights reserved.
// Description: Enumeration of available file sort keys

import Foundation

// MARK: - Sort Keys Enumeration
/// Available sorting criteria for file table columns
enum SortKeysEnum {
    case name
    case date
    case size
    case type
    case permissions
    case owner
    case childCount
}
