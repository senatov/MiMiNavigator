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

    // MARK: -
    init(timestamp: Date) {
       
        log.info(#function)
        self.timestamp = timestamp
    }

    // MARK: -
    public var description: String {
        "Item(timestamp: \(timestamp))"
    }
}
