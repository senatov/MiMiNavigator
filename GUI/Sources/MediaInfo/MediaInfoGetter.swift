//
//  MediaInfoGetter.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import MediaMetadataKit
import FileModelKit

final class MediaInfoGetter: @unchecked Sendable {
    @MainActor
    func getMediaInfoToFile(
        url: URL,
        fast: Bool = false,
        panelSide: FavPanelSide? = nil,
        appState: AppState? = nil
    ) {
        let panelTitle = MediaInfoPanel.windowTitle
        log.info("[MediaInfo] request file='\(url.path)'")

        MediaInfoPanel.shared.show(
            title: panelTitle,
            text: "Processing…",
            url: url,
            panelSide: panelSide,
            appState: appState
        )

        let presentationID = MediaInfoPanel.shared.presentationID
        Task.detached(priority: .userInitiated) { [url, fast, panelTitle, presentationID] in
            let (info, coords) = await MediaInfoReportBuilder.build(url: url, fast: fast)
            await MainActor.run {
                guard MediaInfoPanel.shared.presentationID == presentationID,
                      MediaInfoPanel.shared.panel?.isVisible == true else { return }
                MediaInfoPanel.shared.update(title: panelTitle, text: info, coordinates: coords)
            }
        }
    }
}
