//
//  TotalCommanderResizableView_Previews.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

//  Description:
//

import SwiftUI

// MARK: - -

struct TotalCommanderResizableView_Previews: PreviewProvider {
    static var previews: some View {
        TotalCommanderResizableView(directoryMonitor: DualDirectoryMonitor(leftDirectory: URL(fileURLWithPath: "/path/to/left"), rightDirectory: URL(fileURLWithPath: "/path/to/right")))
    }
}
