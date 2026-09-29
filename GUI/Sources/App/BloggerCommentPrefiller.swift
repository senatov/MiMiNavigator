// BloggerCommentPrefiller.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Opens the Blogger comment form in Safari and fills it without publishing.

import AppKit

// MARK: - Blogger Comment Prefiller
enum BloggerCommentPrefiller {
    static let commentURL = "https://www.blogger.com/comment/frame/2354835223232421243?po=1629775013590241773"

    // MARK: - Fill Comment
    static func fill(_ comment: String) -> Bool {
        let encoded = Data(comment.utf8).base64EncodedString()
        let javascript = """
        var box = document.querySelector('textarea');
        if (box) { box.value = new TextDecoder().decode(Uint8Array.from(atob('\(encoded)'), c => c.charCodeAt(0))); box.dispatchEvent(new Event('input', {bubbles: true})); box.focus(); 'filled'; } else { 'waiting'; }
        """.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Safari"
            activate
            open location "\(commentURL)"
            repeat 20 times
                delay 0.3
                try
                    if URL of current tab of front window starts with "\(commentURL)" then
                        set fillResult to do JavaScript "\(javascript)" in current tab of front window
                        if fillResult is "filled" then return "filled"
                    end if
                end try
            end repeat
        end tell
        return "unfilled"
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return result?.stringValue == "filled"
    }
}
