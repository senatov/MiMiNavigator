// AppStateProvider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton bridge — lets menu actions (closures) reach the live AppState instance

import Foundation

// MARK: - Strong bridge so menu actions (closures) reach the live AppState instance
// Safe to hold strongly — AppState is app-lifetime singleton owned by SwiftUI @State
@MainActor
final class AppStateProvider {
    static var shared: AppState?
}
