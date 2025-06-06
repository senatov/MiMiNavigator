//
//  PanelSide.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

// MARK: -
import Foundation
import SwiftyBeaver

// MARK: -
public enum PanelSide: Equatable, Codable, Sendable {
    case left
    case right


    // MARK: -
    var opposite: PanelSide {
        switch self {
            case .left: return .right
            case .right: return .left
        }
    }
}
