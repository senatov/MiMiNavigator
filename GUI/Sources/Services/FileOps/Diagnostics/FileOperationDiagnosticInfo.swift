import Foundation

struct FileOperationDiagnosticInfo: Sendable {
    let title: String
    let summary: String
    let details: String
    let path: String
    let progressMessage: String
}
