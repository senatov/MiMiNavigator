//
//  DirectoryModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import Combine
import Foundation
import SwiftUI

// MARK: -
@MainActor
final class DirectoryModel: ObservableObject {
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []
    @Published var leftDirectory: URL = .downloadsDirectory
    @Published var rightDirectory: URL = .desktopDirectory
    @Published var selectedDirectory: URL = .homeDirectory
}
