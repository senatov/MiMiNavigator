// HotKeyAction.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enumeration of all bindable actions in the application

import Foundation

// MARK: - Hot Key Action
/// Every action that can be bound to a keyboard shortcut.
/// New features should register their action here.
enum HotKeyAction: String, CaseIterable, Identifiable, Codable, Sendable {

    // MARK: - File Operations
    case viewFile          = "viewFile"
    case editFile          = "editFile"
    case copyFile          = "copyFile"
    case moveFile          = "moveFile"
    case newFolder         = "newFolder"
    case deleteFile        = "deleteFile"

    // MARK: - Navigation
    case togglePanelFocus  = "togglePanelFocus"
    case moveUp            = "moveUp"
    case moveDown          = "moveDown"
    case openSelected      = "openSelected"
    case parentDirectory   = "parentDirectory"
    case refreshPanels     = "refreshPanels"

    // MARK: - Selection (Total Commander style)
    case toggleMark        = "toggleMark"
    case markByPattern     = "markByPattern"
    case unmarkByPattern   = "unmarkByPattern"
    case invertMarks       = "invertMarks"
    case markAll           = "markAll"
    case unmarkAll         = "unmarkAll"
    case markSameExtension = "markSameExtension"
    case clearSelection    = "clearSelection"

    // MARK: - Search
    case findFiles         = "findFiles"

    // MARK: - Application
    case toggleHiddenFiles = "toggleHiddenFiles"
    case openSettings      = "openSettings"
    case exitApp           = "exitApp"

    var id: String { rawValue }

    // MARK: - Display Name
    var displayName: String {
        switch self {
        case .viewFile:          return "View File"
        case .editFile:          return "Edit File"
        case .copyFile:          return "Copy File"
        case .moveFile:          return "Move File"
        case .newFolder:         return "New Folder"
        case .deleteFile:        return "Delete File"
        case .togglePanelFocus:  return "Toggle Panel Focus"
        case .moveUp:            return "Move Up"
        case .moveDown:          return "Move Down"
        case .openSelected:      return "Open Selected"
        case .parentDirectory:   return "Parent Directory"
        case .refreshPanels:     return "Refresh Panels"
        case .toggleMark:        return "Toggle Mark"
        case .markByPattern:     return "Mark by Pattern"
        case .unmarkByPattern:   return "Unmark by Pattern"
        case .invertMarks:       return "Invert Marks"
        case .markAll:           return "Mark All"
        case .unmarkAll:         return "Unmark All"
        case .markSameExtension: return "Mark Same Extension"
        case .clearSelection:    return "Clear Selection"
        case .findFiles:         return "Find Files"
        case .toggleHiddenFiles: return "Toggle Hidden Files"
        case .openSettings:      return "Open Settings"
        case .exitApp:           return "Exit Application"
        }
    }

    // MARK: - Category
    var category: HotKeyCategory {
        switch self {
        case .viewFile, .editFile, .copyFile, .moveFile, .newFolder, .deleteFile:
            return .fileOperations
        case .togglePanelFocus, .moveUp, .moveDown, .openSelected, .parentDirectory, .refreshPanels:
            return .navigation
        case .toggleMark, .markByPattern, .unmarkByPattern, .invertMarks, .markAll, .unmarkAll, .markSameExtension, .clearSelection:
            return .selection
        case .findFiles:
            return .search
        case .toggleHiddenFiles, .openSettings, .exitApp:
            return .application
        }
    }
}

// MARK: - Category
enum HotKeyCategory: String, CaseIterable, Identifiable, Sendable {
    case fileOperations = "File Operations"
    case navigation     = "Navigation"
    case selection      = "Selection"
    case search         = "Search"
    case application    = "Application"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .fileOperations: return "doc.on.doc"
        case .navigation:     return "arrow.left.arrow.right"
        case .selection:      return "checkmark.circle"
        case .search:         return "magnifyingglass"
        case .application:    return "gearshape"
        }
    }
}
