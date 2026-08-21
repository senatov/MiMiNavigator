// AboutDependencyCatalog.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Third-party components presented by the About window.

import Foundation

// MARK: - AboutDependency
struct AboutDependency: Identifiable {
    let name: String
    let description: String
    let url: String
    let license: String
    var id: String { name }
}

// MARK: - AboutDependencyCatalog
enum AboutDependencyCatalog {
    static let libraries = [
        AboutDependency(name: "GRDB.swift", description: "SQLite persistence and schema migrations", url: "https://github.com/groue/GRDB.swift", license: "MIT"),
        AboutDependency(name: "SwiftyBeaver", description: "Structured application logging", url: "https://github.com/SwiftyBeaver/SwiftyBeaver", license: "MIT"),
        AboutDependency(name: "Citadel", description: "High-level SSH and SFTP client", url: "https://github.com/orlandos-nl/Citadel", license: "MIT"),
        AboutDependency(name: "SwiftNIO SSH security fork", description: "SSH transport with CVE-2026-43798 fix", url: "https://github.com/njacknot/swift-nio-ssh", license: "Apache-2.0"),
        AboutDependency(name: "SwiftNIO", description: "Asynchronous networking foundation", url: "https://github.com/apple/swift-nio", license: "Apache-2.0"),
        AboutDependency(name: "Swift Crypto & ASN.1", description: "Cryptographic and ASN.1 primitives", url: "https://github.com/apple/swift-crypto", license: "Apache-2.0"),
        AboutDependency(name: "BigInt", description: "Arbitrary-precision integers used by SSH", url: "https://github.com/attaswift/BigInt", license: "MIT"),
        AboutDependency(name: "Swift Collections, Atomics, Log & System", description: "Supporting Swift server and systems packages", url: "https://github.com/apple", license: "Apache-2.0")
    ]

    static let externalTools = [
        AboutDependency(name: "7-Zip", description: "Optional extended archive support", url: "https://7-zip.org", license: "LGPL/BSD"),
        AboutDependency(name: "unar", description: "Optional RAR and legacy archive extraction", url: "https://theunarchiver.com/command-line", license: "LGPL-2.1+"),
        AboutDependency(name: "sshpass", description: "Optional password authentication helper", url: "https://sourceforge.net/projects/sshpass/", license: "GPL-2.0"),
        AboutDependency(name: "FFmpeg & ffprobe", description: "Optional media conversion and inspection", url: "https://ffmpeg.org/legal.html", license: "GPL/LGPL"),
        AboutDependency(name: "gifski", description: "Optional high-quality GIF encoder", url: "https://gif.ski", license: "AGPL-3.0"),
        AboutDependency(name: "python-lottie", description: "Optional Lottie JSON and TGS conversion", url: "https://pypi.org/project/lottie/", license: "GPL-3.0"),
        AboutDependency(name: "KDiff3 & external diff tools", description: "Optional file and directory comparison", url: "https://apps.kde.org/kdiff3/", license: "Various")
    ]
}
