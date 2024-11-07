//
//  FileSinglton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//
import Combine

import Combine

class FileSingleton: ObservableObject {
    static let shared = FileSingleton()

    @Published public var leftFiles: [CustomFile] = [] // Files for the left panel
    @Published public var rightFiles: [CustomFile] = [] // Files for the right panel

    private init() {}
}
