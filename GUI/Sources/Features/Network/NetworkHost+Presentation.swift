// NetworkHost+Presentation.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Presentation labels shared by Network Neighborhood views.

import Foundation

// MARK: - Network host presentation
extension NetworkHost {
    var nodeTypeLabel: String {
        switch nodeType {
        case .printer: return "Printer"
        case .mobileDevice: return "Mobile Device"
        case .fileServer: return "File Server"
        case .generic: return "Network Device"
        }
    }
}
