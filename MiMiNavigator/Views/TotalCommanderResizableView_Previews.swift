//
//  TotalCommanderResizableView_Previews.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

//  Description:
//

import Foundation
import SwiftUI
import SwiftyBeaver

// MARK: - -

struct TotalCommanderResizableView_Previews: PreviewProvider {
    static var previews: some View {
        TotalCommanderResizableView(directoryMonitor:
            DualDirectoryMonitor(leftDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly")
                                 , rightDirectory: URL(fileURLWithPath: "/Users/senat/Downloads/Hahly")))
    }
}
