// ArchiveExtractor.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive extraction — ZIP, TAR family, 7z with progress + cancel

import Foundation

// MARK: - Archive Extractor

enum ArchiveExtractor {

    typealias ProgressLine = @Sendable (String) -> Void

    /// Force UTF-8 locale for CLI tools — fixes garbled Cyrillic/CJK filenames
    private static func utf8Env() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["LANG"] = "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"
        return env
    }

    @concurrent static func extract(
        archiveURL: URL,
        format: ArchiveFormat,
        to destination: URL,
        password: String? = nil,
        onProgress: ProgressLine? = nil,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws {
        switch format {
        case .zip:
            try await extractZip(
                archiveURL: archiveURL,
                to: destination,
                password: password,
                onProgress: onProgress,
                handle: processHandle
            )
        case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz:
            try await extractTar(
                archiveURL: archiveURL,
                format: format,
                to: destination,
                onProgress: onProgress,
                handle: processHandle
            )
        case .gzip, .bzip2, .xz, .lzma, .zstd, .lz4, .lzo, .lzip, .compressZ:
            try await extractSingleCompressedFile(
                archiveURL: archiveURL,
                format: format,
                to: destination,
                onProgress: onProgress,
                handle: processHandle
            )
        case .sevenZip, .sevenZipGeneric:
            try await extract7z(
                archiveURL: archiveURL,
                to: destination,
                password: password,
                onProgress: onProgress,
                handle: processHandle
            )
        }

        log.info("[Extractor] Done: \(archiveURL.lastPathComponent)")
    }

    // MARK: - Process Helpers
    private static func makeProcess(executablePath: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.environment = utf8Env()
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        return process
    }

    @concurrent private static func runProcess(
        _ process: Process,
        errorPipe: Pipe,
        outputPipe: Pipe,
        onProgress: ProgressLine?
    ) async throws {
        try await ArchiveProcessRunner.runWithProgress(
            process,
            errorPipe: errorPipe,
            outputPipe: outputPipe,
            onLine: onProgress
        )
    }

    // MARK: - ZIP

    @concurrent private static func extractZip(
        archiveURL: URL, to destination: URL,
        password: String?, onProgress: ProgressLine?, handle: ActiveArchiveProcess?
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = makeProcess(executablePath: "/usr/bin/unzip")
        var args = ["-o", "-DD"]

        if let pwd = password, !pwd.isEmpty {
            args += ["-P", pwd]
        }

        args += [archiveURL.path, "-d", destination.path]
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        handle?.set(process)

        try await runProcess(process, errorPipe: errPipe, outputPipe: outPipe, onProgress: onProgress)
    }

    // MARK: - TAR family

    @concurrent private static func extractTar(
        archiveURL: URL, format: ArchiveFormat, to destination: URL,
        onProgress: ProgressLine?, handle: ActiveArchiveProcess?
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = makeProcess(executablePath: "/usr/bin/tar")
        var args = ["-xv"]

        switch format {
        case .tarGz:
            args.append("-z")
        case .tarBz2:
            args.append("-j")
        case .tarXz:
            args.append("-J")
        default:
            break
        }

        args += ["-f", archiveURL.path, "-C", destination.path]
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        handle?.set(process)

        do {
            try await runProcess(process, errorPipe: errPipe, outputPipe: outPipe, onProgress: onProgress)
        } catch {
            log.warning("[Extractor] tar failed for \(archiveURL.lastPathComponent), trying 7z: \(error)")
            try await extract7z(
                archiveURL: archiveURL,
                to: destination,
                password: nil,
                onProgress: onProgress,
                handle: handle
            )
        }
    }

    // MARK: - Single-file compressed formats
    @concurrent private static func extractSingleCompressedFile(
        archiveURL: URL,
        format: ArchiveFormat,
        to destination: URL,
        onProgress: ProgressLine?,
        handle: ActiveArchiveProcess?
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = makeProcess(executablePath: try ArchiveToolLocator.find7z())
        let outputName = archiveURL.deletingPathExtension().lastPathComponent
        let outputPath = destination.appendingPathComponent(outputName).path

        let args = ["x", archiveURL.path, "-o\(destination.path)", "-y", "-bb1"]
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        handle?.set(process)

        do {
            try await runProcess(process, errorPipe: errPipe, outputPipe: outPipe, onProgress: onProgress)
        } catch {
            log.warning("[Extractor] single-file extraction failed for \(archiveURL.lastPathComponent): \(error)")
            throw error
        }

        switch format {
        case .gzip, .bzip2, .xz, .lzma, .zstd, .lz4, .lzo, .lzip, .compressZ:
            if !FileManager.default.fileExists(atPath: outputPath) {
                log.debug("[Extractor] expected single-file output not found: \(outputPath)")
            }
        default:
            break
        }
    }

    // MARK: - 7z

    @concurrent private static func extract7z(
        archiveURL: URL, to destination: URL,
        password: String?, onProgress: ProgressLine?, handle: ActiveArchiveProcess?
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = makeProcess(executablePath: try ArchiveToolLocator.find7z())
        var args = ["x", archiveURL.path, "-o\(destination.path)", "-y", "-bb1"]

        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }

        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        handle?.set(process)

        try await runProcess(process, errorPipe: errPipe, outputPipe: outPipe, onProgress: onProgress)
    }
}
