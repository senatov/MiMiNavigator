// MultiRenameTests.swift
// MiMiNavigatorTests

import Foundation
import XCTest

@testable import MiMiNavigator

// MARK: - Multi Rename Tests
final class MultiRenameTests: XCTestCase {
    func testPatternExpandsNameExtensionAndCounter() {
        let source = MultiRenameSource(url: URL(fileURLWithPath: "/tmp/Report.txt"), isDirectory: false)
        let rule = MultiRenameRule(nameMask: "[C]-[N]", extensionMask: "[E]", counterStart: 7, counterDigits: 3)
        XCTAssertEqual(MultiRenamePattern.proposedName(for: source, index: 0, rule: rule), "007-Report.txt")
    }

    func testPreviewRejectsDuplicateTargets() {
        let sources = [
            MultiRenameSource(url: URL(fileURLWithPath: "/tmp/one.txt"), isDirectory: false),
            MultiRenameSource(url: URL(fileURLWithPath: "/tmp/two.txt"), isDirectory: false),
        ]
        let rule = MultiRenameRule(nameMask: "same", extensionMask: "[E]")
        XCTAssertTrue(MultiRenameEngine.preview(sources: sources, rule: rule).allSatisfy { $0.issue == "Duplicate target name" })
    }

    func testEngineSupportsNameSwap() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)
        let items = [
            MultiRenamePreviewItem(source: MultiRenameSource(url: first, isDirectory: false), proposedName: "second.txt", issue: nil),
            MultiRenamePreviewItem(source: MultiRenameSource(url: second, isDirectory: false), proposedName: "first.txt", issue: nil),
        ]
        let result = try await MultiRenameEngine().rename(items)
        XCTAssertEqual(result.renamedCount, 2)
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "second")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "first")
    }
}
