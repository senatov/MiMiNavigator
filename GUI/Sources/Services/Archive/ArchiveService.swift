// ArchiveService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: High-level archive creation API — delegates packing to Repacker internals

import Foundation

// MARK: - Archive Service
/// Creates new archives from selected files. Delegates to CLI tools via ArchiveProcessRunner.
@MainActor
final class ArchiveService {

    static let shared = ArchiveService()
    private init() {}

    // MARK: - Create Archive

    /// Creates an archive from given files in the specified destination directory.
    func createArchive(
        from files: [URL],
        to destination: URL,
        archiveName: String,
        format: ArchiveFormat,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil,
        onProgress: (@Sendable (String) -> Void)? = nil,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws -> URL {
        guard !files.isEmpty else {
            throw ArchiveManagerError.repackFailed("No files provided")
        }
        let archiveURL = destination.appendingPathComponent("\(archiveName).\(format.fileExtension)")
        guard !FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw FileOperationError.fileAlreadyExists(archiveURL.lastPathComponent)
        }
        let parentDirectories = Set(files.map { $0.deletingLastPathComponent().path })
        guard parentDirectories.count == 1, let workDirPath = parentDirectories.first else {
            throw ArchiveManagerError.repackFailed("All files must be in the same directory")
        }
        let workDir = URL(fileURLWithPath: workDirPath, isDirectory: true)
        try await pack(files: files, to: archiveURL, format: format, workDir: workDir, compressionLevel: compressionLevel, password: password, onProgress: onProgress, processHandle: processHandle)
        log.info("[ArchiveService] Created: \(archiveURL.lastPathComponent) level=\(compressionLevel)")
        return archiveURL
    }

    // MARK: - Private

    private func pack(files: [URL], to archiveURL: URL, format: ArchiveFormat, workDir: URL, compressionLevel: CompressionLevel = .normal, password: String? = nil, onProgress: (@Sendable (String) -> Void)? = nil, processHandle: ActiveArchiveProcess? = nil) async throws {
        let names = files.map(\.lastPathComponent)
        let errorPipe = Pipe()
        let process = Process()
        process.currentDirectoryURL = workDir

        // force UTF-8 output from CLI tools — prevents garbled Cyrillic/CJK filenames
        var baseEnv = ProcessInfo.processInfo.environment
        baseEnv["LANG"] = "en_US.UTF-8"
        baseEnv["LC_ALL"] = "en_US.UTF-8"

        let level = compressionLevel.rawValue

        switch format {
        case .zip:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            var args = ["-\(level)", "-r"]
            if let pwd = password, !pwd.isEmpty {
                args += ["-e", "-P", pwd]
            }
            args += [archiveURL.path] + names
            process.arguments = args

        case .tar:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .tarGz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            var env = baseEnv
            env["GZIP"] = "-\(level)"
            process.environment = env
            process.arguments = ["-c", "-z", "-f", archiveURL.path] + names

        case .tarBz2:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            var env = baseEnv
            env["BZIP2"] = "-\(level)"
            process.environment = env
            process.arguments = ["-c", "-j", "-f", archiveURL.path] + names

        case .tarXz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            var env = baseEnv
            env["XZ_OPT"] = "-\(level)"
            process.environment = env
            process.arguments = ["-c", "-J", "-f", archiveURL.path] + names

        case .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .sevenZip, .sevenZipGeneric:
            process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
            var args = ["a", "-mx=\(level)"]
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
            }
            args += [archiveURL.path] + names
            process.arguments = args
        }

        let outputPipe = Pipe()
        // ensure UTF-8 env for all branches (tarGz/tarBz2/tarXz set their own env from baseEnv)
        if process.environment == nil {
            process.environment = baseEnv
        }
        process.standardOutput = onProgress != nil ? outputPipe : nil
        process.standardError = errorPipe
        log.debug("[ArchiveService] \(#function) tool=\(process.executableURL?.path ?? "?") args=\(process.arguments ?? []) workDir=\(workDir.path)")
        processHandle?.set(process)
        try await ArchiveProcessRunner.runWithProgress(process, errorPipe: errorPipe, outputPipe: onProgress != nil ? outputPipe : nil, onLine: onProgress, processHandle: processHandle)
    }
}
