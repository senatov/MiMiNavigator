//
// BreadCrumbView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Breadcrumb trail UI component for representing navigation path
struct BreadCrumbView: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    private let barHeight: CGFloat = 30
    private let separatorWidth: CGFloat = 20  // approximate width of separator + padding
    private let minSegmentWidth: CGFloat = 24 // minimum width for truncated segment "…"

    // MARK: -
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        GeometryReader { geometry in
            let displaySegments = computeDisplaySegments(availableWidth: geometry.size.width)
            
            HStack(alignment: .center, spacing: 4) {
                ForEach(displaySegments.indices, id: \.self) { index in
                    breadcrumbItem(segment: displaySegments[index], index: index)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: barHeight, alignment: .leading)
        }
        .padding(.horizontal, 0)
        .frame(height: barHeight)
        .controlSize(.mini)
    }

    // MARK: - Display segment with original index for navigation
    private struct DisplaySegment: Identifiable {
        let id = UUID()
        let text: String           // displayed text (may be truncated)
        let originalIndex: Int     // index in original pathComponents for navigation
        let fullName: String       // full directory name for tooltip
    }

    // MARK: - Compute segments that fit in available width
    private func computeDisplaySegments(availableWidth: CGFloat) -> [DisplaySegment] {
        let components = pathComponents
        guard !components.isEmpty else { return [] }
        
        // Single component - show as is
        if components.count == 1 {
            return [DisplaySegment(text: components[0], originalIndex: 0, fullName: components[0])]
        }
        
        // Estimate character width (approximate for system font)
        let charWidth: CGFloat = 7.5
        
        // Calculate total separators width
        let totalSeparatorsWidth = CGFloat(components.count - 1) * separatorWidth
        let availableForText = availableWidth - totalSeparatorsWidth - 16 // padding
        
        // Calculate full width needed
        let fullWidths = components.map { CGFloat($0.count) * charWidth }
        let totalFullWidth = fullWidths.reduce(0, +)
        
        // If everything fits, return as is
        if totalFullWidth <= availableForText {
            return components.enumerated().map { index, name in
                DisplaySegment(text: name, originalIndex: index, fullName: name)
            }
        }
        
        // Need to truncate - keep first and last full, truncate middle ones
        var segments = components.enumerated().map { index, name in
            (index: index, name: name, displayName: name, width: fullWidths[index], priority: truncationPriority(index: index, total: components.count, length: name.count))
        }
        
        var currentWidth = totalFullWidth
        
        // Truncate segments by priority (longest middle segments first)
        while currentWidth > availableForText {
            // Find segment with highest truncation priority that can still be truncated
            let truncatable = segments.enumerated().filter { $0.element.displayName.count > 3 }
            guard let targetIdx = truncatable.max(by: { $0.element.priority < $1.element.priority })?.offset
            else { break }
            
            let segment = segments[targetIdx]
            let newDisplayName = truncateMiddle(segment.displayName, maxLength: max(3, segment.displayName.count - 4))
            let newWidth = CGFloat(newDisplayName.count) * charWidth
            let savedWidth = segment.width - newWidth
            
            segments[targetIdx].displayName = newDisplayName
            segments[targetIdx].width = newWidth
            segments[targetIdx].priority = 0 // reduce priority after truncation
            
            currentWidth -= savedWidth
        }
        
        return segments.map { DisplaySegment(text: $0.displayName, originalIndex: $0.index, fullName: $0.name) }
    }
    
    // MARK: - Truncation priority (higher = truncate first)
    private func truncationPriority(index: Int, total: Int, length: Int) -> Int {
        // Never truncate first and last
        if index == 0 || index == total - 1 {
            return 0
        }
        // Priority based on length - longer segments truncated first
        return length * 10
    }
    
    // MARK: - Truncate string in the middle
    private func truncateMiddle(_ str: String, maxLength: Int) -> String {
        guard str.count > maxLength, maxLength >= 3 else { return str }
        let half = (maxLength - 1) / 2
        let prefix = str.prefix(half)
        let suffix = str.suffix(half)
        return "\(prefix)…\(suffix)"
    }

    // MARK: - Path components
    private var pathComponents: [String] {
        let path = (panelSide == .left ? appState.leftPath : appState.rightPath)
        return path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - Breadcrumb item view
    @ViewBuilder
    private func breadcrumbItem(segment: DisplaySegment, index: Int) -> some View {
        if index > 0 {
            Image(systemName: "arrowtriangle.forward")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .foregroundStyle(.secondary)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1)
                .contrast(1.12)
                .saturation(1.06)
                .padding(.horizontal, 2)
        }
        segmentButton(segment: segment)
    }

    // MARK: - Segment button
    private func segmentButton(segment: DisplaySegment) -> some View {
        Button(action: { handlePathSelection(upTo: segment.originalIndex) }) {
            Text(segment.text)
                .font(.callout)
                .foregroundStyle(FilePanelStyle.blueSymlinkDirNameColor)
                .padding(.vertical, 2)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .help(makeHelpTooltip(for: segment.originalIndex, fullName: segment.fullName))
        .contextMenu {
            Button("Copy path") {
                let fullPath = "/" + pathComponents.prefix(segment.originalIndex + 1).joined(separator: "/")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullPath, forType: .string)
            }
        }
    }

    // MARK: - Tooltip helper
    private func makeHelpTooltip(for index: Int, fullName: String) -> String {
        let fullPath = "/" + pathComponents.prefix(index + 1).joined(separator: "/")
        let maxLength = 60
        let displayedPath: String
        if fullPath.count > maxLength {
            let prefix = fullPath.prefix(25)
            let suffix = fullPath.suffix(30)
            displayedPath = "\(prefix)…\(suffix)"
        } else {
            displayedPath = fullPath
        }
        // Show full name if truncated
        if fullName != pathComponents[index] {
            return "📂 \(fullName)\n→ \(displayedPath)"
        }
        return "📂 Open \(displayedPath)"
    }

    // MARK: - Handle Selection
    private func handlePathSelection(upTo index: Int) {
        log.info(#function + " for index \(index) on side <<\(panelSide)>>")
        let newPath = ("/" + pathComponents.prefix(index + 1).joined(separator: "/"))
            .replacingOccurrences(of: "//", with: "/")
            .replacingOccurrences(of: "///", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = (panelSide == .left ? appState.leftPath : appState.rightPath)
        guard toCanonical(newPath) != toCanonical(currentPath) else {
            log.info("Path unchanged, skipping update")
            return
        }
        appState.updatePath(newPath, for: panelSide)
        Task {
            await performDirectoryUpdate(for: panelSide, path: newPath)
        }
    }

    // MARK: - Canonicalize path
    private func toCanonical(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    // MARK: - Perform directory update
    @MainActor
    private func performDirectoryUpdate(for panelSide: PanelSide, path: String) async {
        log.info("Task started for side <<\(panelSide)>> with path: \(path)")
        if panelSide == .left {
            await appState.scanner.setLeftDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .left)
            await appState.refreshLeftFiles()
        } else {
            await appState.scanner.setRightDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .right)
            await appState.refreshRightFiles()
        }
        log.info("Task finished successfully")
    }
}
