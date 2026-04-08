// ExternalToolCatalog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Static catalog of all external tools MiMiNavigator may use.
//   System tools (zip, tar, find) are always present on macOS.
//   Optional tools (7z, sshpass) need brew or manual install.

import Foundation


// MARK: - ExternalToolCatalog

enum ExternalToolCatalog {

    // MARK: - System tools (bundled with macOS)

    static let zip = ExternalTool(
        id: "zip", name: "zip",
        binaryCandidates: ["/usr/bin/zip"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Create ZIP archives",
        isSystemTool: true)

    static let unzip = ExternalTool(
        id: "unzip", name: "unzip",
        binaryCandidates: ["/usr/bin/unzip"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Extract ZIP archives",
        isSystemTool: true)

    static let tar = ExternalTool(
        id: "tar", name: "tar",
        binaryCandidates: ["/usr/bin/tar"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Create/extract tar archives",
        isSystemTool: true)

    static let ditto = ExternalTool(
        id: "ditto", name: "ditto",
        binaryCandidates: ["/usr/bin/ditto"],
        brewFormula: nil, websiteURL: nil,
        purpose: "macOS archive tool with resource fork support",
        isSystemTool: true)

    static let find = ExternalTool(
        id: "find", name: "find",
        binaryCandidates: ["/usr/bin/find"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Search for files in directory hierarchy",
        isSystemTool: true)

    static let ssh = ExternalTool(
        id: "ssh", name: "ssh",
        binaryCandidates: ["/usr/bin/ssh"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Secure shell connections",
        isSystemTool: true)

    static let scp = ExternalTool(
        id: "scp", name: "scp",
        binaryCandidates: ["/usr/bin/scp"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Secure file copy over SSH",
        isSystemTool: true)

    static let smbutil = ExternalTool(
        id: "smbutil", name: "smbutil",
        binaryCandidates: ["/usr/bin/smbutil"],
        brewFormula: nil, websiteURL: nil,
        purpose: "SMB/CIFS network share enumeration",
        isSystemTool: true)

    static let nslookup = ExternalTool(
        id: "nslookup", name: "nslookup",
        binaryCandidates: ["/usr/bin/nslookup"],
        brewFormula: nil, websiteURL: nil,
        purpose: "DNS name resolution",
        isSystemTool: true)

    static let curl = ExternalTool(
        id: "curl", name: "curl",
        binaryCandidates: ["/usr/bin/curl"],
        brewFormula: nil, websiteURL: nil,
        purpose: "FTP/HTTP file transfer",
        isSystemTool: true)

    static let open = ExternalTool(
        id: "open", name: "open",
        binaryCandidates: ["/usr/bin/open"],
        brewFormula: nil, websiteURL: nil,
        purpose: "Open files & apps via Launch Services",
        isSystemTool: true)

    static let opendiff = ExternalTool(
        id: "opendiff", name: "opendiff",
        binaryCandidates: ["/usr/bin/opendiff"],
        brewFormula: nil, websiteURL: nil,
        purpose: "FileMerge diff tool (requires Xcode CLI tools)",
        isSystemTool: true)


    // MARK: - Optional tools (require installation)

    static let sevenZip = ExternalTool(
        id: "7z", name: "7-Zip",
        binaryCandidates: ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/opt/homebrew/bin/7zz", "/usr/local/bin/7zz"],
        brewFormula: "7zip",
        websiteURL: "https://www.7-zip.org",
        purpose: "7z, RAR, ISO and 30+ archive formats",
        isSystemTool: false)

    static let sshpass = ExternalTool(
        id: "sshpass", name: "sshpass",
        binaryCandidates: ["/opt/homebrew/bin/sshpass", "/usr/local/bin/sshpass"],
        brewFormula: "sshpass",
        websiteURL: "https://sourceforge.net/projects/sshpass/",
        purpose: "Non-interactive SSH password auth",
        isSystemTool: false)


    // MARK: - Brew itself

    static let brew = ExternalTool(
        id: "brew", name: "Homebrew",
        binaryCandidates: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"],
        brewFormula: nil,
        websiteURL: "https://brew.sh",
        purpose: "macOS package manager — needed to install optional tools",
        isSystemTool: false)


    // MARK: - All tools

    static let allTools: [ExternalTool] = [
        zip, unzip, tar, ditto, find,
        ssh, scp, smbutil, nslookup, curl, open, opendiff,
        sevenZip, sshpass,
    ]


    static let optionalTools: [ExternalTool] = allTools.filter { !$0.isSystemTool }
}
