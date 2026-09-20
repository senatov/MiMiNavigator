# Third-Party Notices

This document describes third-party software used by MiMiNavigator. Swift package versions are taken from the committed `Package.resolved` file. Optional command-line tools are installed separately by the user and are not distributed inside the application bundle.

## Linked Swift packages

| Component | Resolved version | License | Source |
|---|---:|---|---|
| SwiftyBeaver | 2.1.1 | MIT | <https://github.com/SwiftyBeaver/SwiftyBeaver> |
| GRDB.swift | 7.11.1 | MIT | <https://github.com/groue/GRDB.swift> |
| Citadel | 0.12.1 | MIT | <https://github.com/orlandos-nl/Citadel> |
| SwiftNIO SSH security fork | 0.3.7 | Apache-2.0 | <https://github.com/njacknot/swift-nio-ssh> |
| SwiftNIO | 2.101.3 | Apache-2.0 | <https://github.com/apple/swift-nio> |
| Swift Crypto | 3.15.1 | Apache-2.0 | <https://github.com/apple/swift-crypto> |
| Swift ASN.1 | 1.7.1 | Apache-2.0 | <https://github.com/apple/swift-asn1> |
| Swift Atomics | 1.3.1 | Apache-2.0 | <https://github.com/apple/swift-atomics> |
| Swift Collections | 1.6.0 | Apache-2.0 | <https://github.com/apple/swift-collections> |
| Swift Log | 1.15.0 | Apache-2.0 | <https://github.com/apple/swift-log> |
| Swift System | 1.8.1 | Apache-2.0 | <https://github.com/apple/swift-system> |
| BigInt | 5.7.0 | MIT | <https://github.com/attaswift/BigInt> |

The SwiftNIO SSH package is mirrored to the compatible 0.3.7 security fork because Citadel currently requires its fork-specific API and a version below 0.4.0. Version 0.3.7 carries the upstream fix for CVE-2026-43798. BigInt 5.x and Swift Crypto 3.x are the newest major versions allowed by the current Citadel dependency graph.

The complete license text for every linked package is available in the `LICENSE` or `LICENSE.txt` file at the corresponding source link. MIT and Apache-2.0 notices and attribution requirements remain applicable to redistributed binaries and source code.

## Adapted source components

The compact toolbar sparkline is adapted from Hop: <https://github.com/antonyshakirov/hop>.

MIT License

Copyright (c) 2026 Anton Shakirov

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Optional external tools

| Component | Purpose | License | Source |
|---|---|---|---|
| 7-Zip | Extended archive formats | LGPL-2.1-or-later and BSD-3-Clause | <https://7-zip.org> |
| unar | RAR and legacy archive extraction | LGPL-2.1-or-later | <https://theunarchiver.com/command-line> |
| sshpass | Non-interactive SSH password authentication | GPL-2.0-only | <https://sourceforge.net/projects/sshpass/> |
| FFmpeg and ffprobe | Media conversion and inspection | GPL/LGPL, depending on build | <https://ffmpeg.org/legal.html> |
| gifski | High-quality GIF encoding | AGPL-3.0-only | <https://gif.ski> |
| python-lottie | Lottie JSON and TGS conversion | GPL-3.0 | <https://pypi.org/project/lottie/> |
| KDiff3 | File and directory comparison | GPL-2.0-or-later | <https://apps.kde.org/kdiff3/> |

MiMiNavigator only discovers and launches these separately installed programs. Their executables are not linked into or bundled with MiMiNavigator.

## Apple platform technologies

SwiftUI, AppKit, CryptoKit, SQLite, VideoToolbox, ImageIO, Network, Uniform Type Identifiers, Quick Look, and other Apple SDK frameworks are platform components governed by the applicable Apple SDK terms. They are not third-party packages shipped by this repository.
