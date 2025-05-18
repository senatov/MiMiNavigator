//
//  Item.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import Foundation
import SwiftData

@Model
final class Item: CustomStringConvertible {

    public var description: String {
        "description"
    }

    var timestamp: Date

    init(timestamp: Date) {
        log.debug(#function)
        self.timestamp = timestamp
    }
}
