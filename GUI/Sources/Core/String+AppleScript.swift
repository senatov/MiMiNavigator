import Foundation

extension String {
    /// Wraps string in AppleScript double-quoted string, escaping backslashes and double-quotes.
    /// Use for inserting Swift strings into AppleScript source via string interpolation.
    ///
    /// Example:
    ///   let path = "/Users/foo/my \"docs\""
    ///   let script = "keystroke \(path.appleScriptQuoted)"
    ///   → keystroke "/Users/foo/my \"docs\""
    var appleScriptQuoted: String {
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
