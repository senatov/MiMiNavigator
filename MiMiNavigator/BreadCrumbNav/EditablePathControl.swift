//
//  EditablePathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

/// A view displaying a breadcrumb-style editable path bar with panel navigation menus.
struct EditablePathControl: View {
    @EnvironmentObject var appState: AppState

    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 2) {
            NavMnu1()
            Spacer(minLength: 3)
            BreadCrumbView().environmentObject(appState)
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.background)
        )
    }

}
