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
public enum PanelSide: Equatable, Codable, Sendable, CustomStringConvertible {
    case left
    case right
    
    public static let leftString = "left"
    public static let rightString = "right"
    
        // MARK: -
    public var stringValue: String {
        switch self {
            case .left: return Self.leftString
            case .right: return Self.rightString
        }
    }
        // MARK: -
    public static func from(string: String) -> PanelSide? {
        switch string.lowercased() {
            case leftString: return .left
            case rightString: return .right
            default: return nil
        }
    }
    
        // MARK: -
    public var description: String {
        return self.stringValue
    }
}
