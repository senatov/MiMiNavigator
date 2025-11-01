//
//  ToolTipConfig.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 02.11.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Configuration
public struct ToolTipConfig: Sendable {
    public var size: CGSize = CGSize(width: 180, height: 50)
    public var cornerRadius: CGFloat = 18
    public var tailLength: CGFloat = 54
    public var tailWidth: CGFloat = 16
    public var tailDirection: SpeechBubbleShape.Direction = .left
    public var tailOffset: CGFloat = 0
    public init() {}
    public static let `default` = ToolTipConfig()
}
