    //
    //  SelectedDir.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 10.05.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

public class SelectedDir: ObservableObject {

        // TODO: Currently initialized, but should be saved in UserDefaults or other persistent storage
    @Published var selectedDir: CustomFile

    init() {
        if let savedPath = UserDefaults.standard.string(forKey: "SelectedDirPath") {
            let url = URL(fileURLWithPath: savedPath)
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            self.selectedDir = CustomFile(name: name, path: savedPath, isDirectory: isDirectory)
        } else {
            self.selectedDir = CustomFile(name: "/", path: "/", isDirectory: true)  // Default value
        }
    }
}
