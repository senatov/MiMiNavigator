// ColumnAutoFitMeasurerTests.swift
// MiMiNavigatorTests
//
// Created by Iakov Senatov on 23.07.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import Foundation
import Testing

@testable import MiMiNavigator

// MARK: - Column Auto Fit Measurer Tests
struct ColumnAutoFitMeasurerTests {
    @Test func kindWidthIncludesRenderedPaddingAndTextReserve() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("sample.cdd")
        try Data().write(to: fileURL)
        let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let file = CustomFile(url: fileURL, resourceValues: values)
        let fittedWidth = ColumnAutoFitMeasurer.contentWidth(for: .kind, files: [file])
        let font = NSFont.systemFont(ofSize: 12)
        let textWidth = ("CDD" as NSString).size(withAttributes: [.font: font]).width
        let padding = ColumnID.kind.contentPadding.leading + ColumnID.kind.contentPadding.trailing
        #expect(fittedWidth >= ceil(textWidth + padding + ColumnAutoFitMetrics.textRenderingReserve))
    }
}
