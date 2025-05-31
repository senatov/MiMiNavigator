//
//  DirectorySide.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

// MARK: -
public enum DirectorySide: CustomStringConvertible {
    case left, right
    public var description: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        }
    }
}
