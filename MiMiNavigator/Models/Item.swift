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

    var timestamp: Date

    init(timestamp: Date) {
        log.debug(#function)
        self.timestamp = timestamp
    }

    public var description: String {
        "Item(timestamp: \(timestamp))"
    }
}
