// AppConstants.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

// MARK: - Centralized application constants
enum AppConstants {
    
    // MARK: - File scanning limits
    enum Scanning {
        /// Maximum directories to scan in favorites tree
        static let maxDirectories = 64
        
        /// Maximum depth for recursive directory scanning
        static let maxDepth = 2
        
        /// Refresh interval for directory monitoring (seconds)
        static let refreshInterval: TimeInterval = 60
    }
    
    // MARK: - History limits
    enum History {
        /// Maximum entries in navigation history
        static let maxEntries = 50
        
        /// Maximum entries to show in history popover
        static let popoverLimit = 20
    }
    
    // MARK: - UI limits
    enum UI {
        /// Maximum path display length before truncation
        static let maxPathDisplayLength = 256
        
        /// Maximum name display width in tree views
        static let maxNameDisplayWidth = 75
    }
    
}
