//
//  Folders.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import Combine
import Foundation
import SwiftUI

public class Folders: ObservableObject {

    @Published var leftDirectory: URL = URL.documentsDirectory
    @Published var rightDirectory: URL = URL.downloadsDirectory
    @Published var selectedDirectory: URL = URL.documentsDirectory
    @Published var leftFiles: [CustomFile] = []
    @Published var rightFiles: [CustomFile] = []

}
