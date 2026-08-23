import Foundation

// MARK: - Media Conversion Phase
enum MediaConversionPhase: Sendable, Equatable {
    case idle
    case preparing
    case running(tool: String)
    case awaitingDecision(reason: String)
    case completed(output: URL)
    case failed(message: String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .preparing, .running, .awaitingDecision: return true
        case .idle, .completed, .failed, .cancelled: return false
        }
    }
}
