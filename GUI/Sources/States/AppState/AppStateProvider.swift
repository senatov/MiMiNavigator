// AppStateProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton bridge — lets menu actions (closures) reach the live AppState instance

import Foundation

// MARK: - Weak bridge so menu closures can call AppState without @Environment
@MainActor
final class AppStateProvider {
    static weak var shared: AppState?
}
