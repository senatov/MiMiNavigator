// MediaConversionService+Output.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - Conversion output safety
@MainActor
extension MediaConversionService {
    // MARK: - Resolve output conflict
    func resolveDestination(source: URL, requested: URL) async throws -> URL {
        let directory = requested.deletingLastPathComponent()
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ConversionError.writeFailed("Output folder does not exist: \(directory.path)")
        }
        guard !requested.lastPathComponent.isEmpty, requested.lastPathComponent != ".", requested.lastPathComponent != ".." else {
            throw ConversionError.writeFailed("Invalid output filename")
        }
        guard FileManager.default.fileExists(atPath: requested.path) else { return requested }
        var targetIsDirectory = ObjCBool(false)
        _ = FileManager.default.fileExists(atPath: requested.path, isDirectory: &targetIsDirectory)
        guard !targetIsDirectory.boolValue else { throw ConversionError.writeFailed("Output name belongs to a folder") }
        let choice = await ErrorAlertService.choose(
            title: "Output Already Exists",
            message: "A file named \(requested.lastPathComponent) already exists in the output folder.",
            buttons: ["Keep Both", "Replace", "Cancel"],
            style: .warning
        )
        switch choice {
        case 0:
            return try uniqueDestination(source: source, requested: requested)
        case 1:
            try Self.validateDestination(source: source, target: requested)
            return requested
        default:
            throw CancellationError()
        }
    }

    // MARK: - Generate a free output name
    func uniqueDestination(source: URL, requested: URL) throws -> URL {
        let directory = requested.deletingLastPathComponent()
        let name = requested.deletingPathExtension().lastPathComponent
        let ext = requested.pathExtension
        for number in 2...10_000 {
            let candidate = directory.appendingPathComponent("\(name) \(number)").appendingPathExtension(ext)
            if candidate.standardizedFileURL.resolvingSymlinksInPath() == source.standardizedFileURL.resolvingSymlinksInPath() { continue }
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        throw ConversionError.writeFailed("No free output filename found")
    }

    // MARK: - Prepare a sibling temporary file
    func stagedOutputURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appendingPathComponent(".mimi-convert-\(UUID().uuidString)")
            .appendingPathExtension(destination.pathExtension)
    }

    // MARK: - Install verified result
    func installStagedOutput(_ staged: URL, at destination: URL, replaceExisting: Bool) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: staged.path)
        guard (attributes[.size] as? NSNumber)?.uint64Value ?? 0 > 0 else {
            throw ConversionError.writeFailed("Converter produced an empty file")
        }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: staged, to: destination)
            return
        }
        guard replaceExisting else { throw ConversionError.writeFailed("Output appeared while converting: \(destination.lastPathComponent)") }
        var targetIsDirectory = ObjCBool(false)
        _ = fileManager.fileExists(atPath: destination.path, isDirectory: &targetIsDirectory)
        guard !targetIsDirectory.boolValue else { throw ConversionError.writeFailed("Output name belongs to a folder") }
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".mimi-replaced-\(UUID().uuidString)")
            .appendingPathExtension(destination.pathExtension)
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: staged, to: destination)
            do { try fileManager.removeItem(at: backup) }
            catch { log.warning("[MediaConvert] replaced file backup remains at \(backup.path): \(error.localizedDescription)") }
        } catch {
            do { try fileManager.moveItem(at: backup, to: destination) }
            catch { log.error("[MediaConvert] output recovery failed backup=\(backup.path) error=\(error.localizedDescription)") }
            throw error
        }
    }
}
