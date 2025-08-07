//
//  FileScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import Combine
import Foundation
import SwiftyBeaver

final class FileScanner {

    // MARK: -
    static func scan(url: URL) throws -> [CustomFile] {
        log.info(#function)
        var result: [CustomFile] = []
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for fileURL in contents {
            let customFile = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
            result.append(customFile)
        }
        return result
    }
}
