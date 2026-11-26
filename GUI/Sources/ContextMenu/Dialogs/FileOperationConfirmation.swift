import Foundation

// MARK: - File Operation Confirmation
enum FileOperationConfirmation {
    static let key = "fileOperationConfirmationThreshold"
    static let defaultThreshold = 5
    static let thresholdRange = 0...15

    // MARK: - Confirmation Policy
    static func isRequired(for itemCount: Int) -> Bool {
        let defaults = UserDefaults.standard
        let threshold = defaults.object(forKey: key) == nil ? defaultThreshold : defaults.integer(forKey: key)
        let limit = min(max(threshold, thresholdRange.lowerBound), thresholdRange.upperBound)
        return limit > 0 && itemCount > limit
    }
}
