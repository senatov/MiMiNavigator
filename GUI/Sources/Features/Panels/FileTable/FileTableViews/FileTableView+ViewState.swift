//
//  FileTableView+ViewState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

//
//  FileTableView+ViewState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

extension FileTableView {
    // MARK: - View State
    var currentPanelPath: String {
        appState.path(for: panelSide)
    }

    /// Lightweight metadata signature for visible rows.
    /// Used to refresh cached rows when external FSEvents update file metadata
    /// without changing the overall file-id set.
    var filesMetadataSignature: Int {
        var hasher = Hasher()
        hasher.combine(files.count)

        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.nameStr)
            hasher.combine(file.pathStr)
            hasher.combine(file.isDirectory)
            hasher.combine(file.cachedDirectorySize)
            hasher.combine(file.sizeInBytes)
            hasher.combine(file.sizeIsExact)
            hasher.combine(file.modifiedDate?.timeIntervalSince1970 ?? 0)
            hasher.combine(String(describing: file.securityState))
        }

        return hasher.finalize()
    }

    var isMenuTracking: Bool {
        activeMenuTrackingCount > 0
    }

    // MARK: - View Composition
    var contentView: some View {
        ZStack {
            mainScrollView

            AppKitDropView(
                panelSide: panelSide,
                appState: appState,
                dragDropManager: dragDropManager
            )

            DragOverlayView(panelSide: panelSide)

            if showSpinner {
                spinnerView
            }
        }
    }

    var spinnerView: some View {
        ProgressView()
            .controlSize(.small)
            .scaleEffect(0.9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    var styledContentView: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 6)
            .padding(.trailing, ScrollBarConfig.trailingPadding)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(panelBorder)
            .contentShape(Rectangle())
            .animation(nil as Animation?, value: isFocused)
            .animation(nil as Animation?, value: selectedID)
            .animation(nil as Animation?, value: filesVersion)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
            .focusable(true)
            .focusEffectDisabled()
            .onGeometryChange(
                for: CGFloat.self,
                of: { geometry in geometry.size.height }
            ) { newHeight in
                viewHeight = newHeight
            }
            .onChange(of: layout.containerWidth) { _, newWidth in
                handleContainerWidthChange(newWidth)
            }
            .onChange(of: filesVersion) { _, newValue in
                handleFilesVersionChange(newValue)
            }
            .onChange(of: filesMetadataSignature) { _, _ in
                handleFilesMetadataChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
                handleMenuTrackingBegan()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
                handleMenuTrackingEnded()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                handleAppDidBecomeActive()
            }
            .onChange(of: appState.sortKey) { _, newValue in
                handleSortChange(newValue)
            }
            .onChange(of: appState.bSortAscending) { _, newValue in
                handleSortChange(newValue)
            }
            .onChange(of: selectedID) { _, newValue in
                handleSelectionChange(newValue)
            }
            .onChange(of: selectedFileIDFromState) { _, newValue in
                syncSelectionFromState(newValue)
            }
            .onChange(of: isLoading) { _, loading in
                handleLoadingChange(loading)
            }
            .onKeyPress(.upArrow, action: handleUpArrow)
            .onKeyPress(.downArrow, action: handleDownArrow)
            .onKeyPress(.pageUp, action: handlePageUp)
            .onKeyPress(.pageDown, action: handlePageDown)
            .onKeyPress(.home, action: handleHome)
            .onKeyPress(.end, action: handleEnd)
            .onKeyPress(.escape, action: handleEscape)
            .onReceive(jumpToFirstPublisher, perform: handleJumpToFirst)
            .onReceive(jumpToLastPublisher, perform: handleJumpToLast)
            .onDisappear {
                spinnerTask?.cancel()
                pendingAutoFitTask?.cancel()
                deferredFilesVersion = nil
                activeMenuTrackingCount = 0
            }
    }
}
