//
//  RemoteConnection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Connection state for a single remote session
struct RemoteConnection: Identifiable {
    let id: UUID
    let server: RemoteServer
    let provider: any RemoteFileProvider
    let connectedAt: Date
    var currentPath: String

    var displayName: String { server.displayName }
    var protocolType: RemoteProtocol { server.remoteProtocol }
}
