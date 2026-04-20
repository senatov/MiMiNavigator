import Foundation

enum FileOperationDiagnostics {
    static func makeProtectedDelete(source: URL) -> FileOperationDiagnosticInfo {
        let normalizedPath = source.resolvingSymlinksInPath().path
        let details = [
            "Operation: Delete",
            "Path: \(normalizedPath)",
            "Reason: This file is an active MiMiNavigator log destination.",
            "Hint: Stop MiMiNavigator first, then remove or rotate the log file."
        ].joined(separator: "\n")

        return FileOperationDiagnosticInfo(
            title: "Delete Blocked",
            summary: "\"\(source.lastPathComponent)\" is currently used by MiMiNavigator logging.",
            details: details,
            path: normalizedPath,
            progressMessage: "\(source.lastPathComponent): active app log file"
        )
    }

    static func makeDelete(source: URL, error: Error) -> FileOperationDiagnosticInfo {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let effectiveError = underlying ?? nsError

        var lines: [String] = []
        lines.append("Operation: Delete")
        lines.append("Path: \(source.path)")
        lines.append("Domain: \(effectiveError.domain)")
        lines.append("Code: \(effectiveError.code)")
        lines.append("Reason: \(effectiveError.localizedDescription)")

        if let hint = hintText(for: effectiveError) {
            lines.append("Hint: \(hint)")
        }

        let lockingProcesses = lockingProcessDescriptions(for: source)
        if !lockingProcesses.isEmpty {
            lines.append("Locked by: \(lockingProcesses.joined(separator: ", "))")
        }

        return FileOperationDiagnosticInfo(
            title: "Delete Failed",
            summary: summaryText(prefix: "deleted", source: source, error: effectiveError),
            details: lines.joined(separator: "\n"),
            path: source.path,
            progressMessage: progressText(for: source, error: effectiveError)
        )
    }

    static func make(
        operation: FileOpType,
        source: URL,
        target: URL? = nil,
        error: Error
    ) -> FileOperationDiagnosticInfo {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let effectiveError = underlying ?? nsError

        var lines: [String] = []
        lines.append("Operation: \(operation.title)")
        lines.append("Path: \(source.path)")
        if let target {
            lines.append("Target: \(target.path)")
        }
        lines.append("Domain: \(effectiveError.domain)")
        lines.append("Code: \(effectiveError.code)")
        lines.append("Reason: \(effectiveError.localizedDescription)")

        let summary = summaryText(for: operation, source: source, target: target, error: effectiveError)
        let progressMessage = progressText(for: source, error: effectiveError)

        if let hint = hintText(for: effectiveError) {
            lines.append("Hint: \(hint)")
        }

        let lockingProcesses = lockingProcessDescriptions(for: source)
        if !lockingProcesses.isEmpty {
            lines.append("Locked by: \(lockingProcesses.joined(separator: ", "))")
        }

        return FileOperationDiagnosticInfo(
            title: "\(operation.title) Failed",
            summary: summary,
            details: lines.joined(separator: "\n"),
            path: source.path,
            progressMessage: progressMessage
        )
    }

    private static func summaryText(for operation: FileOpType, source: URL, target: URL?, error: NSError) -> String {
        summaryText(prefix: operation.pastTense.lowercased(), source: source, error: error)
    }

    private static func summaryText(prefix: String, source: URL, error: NSError) -> String {
        let fileName = source.lastPathComponent
        if isPermissionDenied(error) {
            return "\"\(fileName)\" could not be \(prefix) because macOS denied access."
        }
        if isBusyOrLocked(error) {
            return "\"\(fileName)\" is busy or locked by another process."
        }
        return "\"\(fileName)\" could not be \(prefix)."
    }

    private static func progressText(for source: URL, error: NSError) -> String {
        let fileName = source.lastPathComponent
        if isBusyOrLocked(error) {
            return "\(fileName): locked or busy"
        }
        if isPermissionDenied(error) {
            return "\(fileName): permission denied"
        }
        return "\(fileName): \(error.localizedDescription)"
    }

    private static func hintText(for error: NSError) -> String? {
        if isBusyOrLocked(error) {
            return "Close the app using this file and try again."
        }
        if isPermissionDenied(error) {
            return "Check file permissions, Full Disk Access, or whether the destination is protected by macOS."
        }
        switch (error.domain, error.code) {
        case (NSCocoaErrorDomain, NSFileWriteFileExistsError):
            return "A file with the same name already exists."
        default:
            return nil
        }
    }

    private static func isPermissionDenied(_ error: NSError) -> Bool {
        (error.domain == NSPOSIXErrorDomain && (error.code == EPERM || error.code == EACCES))
            || error.code == NSFileReadNoPermissionError
            || error.code == NSFileWriteNoPermissionError
    }

    private static func isBusyOrLocked(_ error: NSError) -> Bool {
        if error.domain == NSPOSIXErrorDomain {
            return error.code == EBUSY || error.code == ETXTBSY
        }
        return error.code == NSFileWriteUnknownError
            || error.localizedDescription.localizedCaseInsensitiveContains("busy")
            || error.localizedDescription.localizedCaseInsensitiveContains("locked")
    }

    private static func lockingProcessDescriptions(for url: URL) -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-Fpc", "--", url.path]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 || process.terminationStatus == 1 else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return [] }

        var pid: String?
        var command: String?
        var results: [String] = []

        for line in text.split(separator: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                pid = value
            case "c":
                command = value
                if let command, let pid {
                    results.append("\(command) (pid \(pid))")
                } else if let command {
                    results.append(command)
                }
            default:
                continue
            }
        }

        return Array(NSOrderedSet(array: results).array as? [String] ?? []).prefix(5).map { $0 }
    }
}
