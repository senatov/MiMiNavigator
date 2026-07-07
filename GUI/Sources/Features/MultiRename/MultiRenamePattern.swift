// MultiRenamePattern.swift
// MiMiNavigator

import Foundation

// MARK: - Multi Rename Pattern
enum MultiRenamePattern {
    static func proposedName(for source: MultiRenameSource, index: Int, rule: MultiRenameRule) -> String {
        let original = source.url.lastPathComponent
        let ext = source.isDirectory ? "" : source.url.pathExtension
        let name = source.isDirectory || ext.isEmpty ? original : source.url.deletingPathExtension().lastPathComponent
        let counter = rule.counterStart + index * rule.counterStep
        let counterText = String(format: "%0*d", max(1, rule.counterDigits), counter)
        var newName = expand(rule.nameMask, name: name, extension: ext, counter: counterText)
        let newExtension = source.isDirectory ? "" : expand(rule.extensionMask, name: name, extension: ext, counter: counterText)
        newName = replace(in: newName, rule: rule)
        let transformedName = applyCase(newName, mode: rule.caseMode)
        let transformedExtension = applyCase(newExtension, mode: rule.caseMode)
        return transformedExtension.isEmpty ? transformedName : "\(transformedName).\(transformedExtension)"
    }

    private static func expand(_ mask: String, name: String, extension ext: String, counter: String) -> String {
        mask.replacingOccurrences(of: "[N]", with: name)
            .replacingOccurrences(of: "[E]", with: ext)
            .replacingOccurrences(of: "[C]", with: counter)
    }

    private static func replace(in value: String, rule: MultiRenameRule) -> String {
        guard !rule.searchText.isEmpty else { return value }
        if rule.useRegex {
            let options: NSRegularExpression.Options = rule.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: rule.searchText, options: options) else { return value }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return regex.stringByReplacingMatches(in: value, range: range, withTemplate: rule.replacementText)
        }
        let options: String.CompareOptions = rule.caseSensitive ? [] : [.caseInsensitive]
        return value.replacingOccurrences(of: rule.searchText, with: rule.replacementText, options: options)
    }

    private static func applyCase(_ value: String, mode: MultiRenameCaseMode) -> String {
        switch mode {
        case .unchanged: return value
        case .lowercase: return value.lowercased()
        case .uppercase: return value.uppercased()
        case .capitalized: return value.capitalized
        }
    }
}
