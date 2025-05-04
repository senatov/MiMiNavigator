//
//  Item.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.08.24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        log.debug(#function)
        self.timestamp = timestamp
    }
}
