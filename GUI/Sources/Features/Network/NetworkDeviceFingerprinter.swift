// NetworkDeviceFingerprinter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Refactored: 22.02.2026 — iPhone/iPad detection; fritz by name; localhost = Mac
// Refactored: 22.02.2026 — mac hostname keywords (macpro/macbook/imac); vuduo=NAS
// Copyright © 2026 Senatov. All rights reserved.
// Description: Determines hardware type by Bonjour services + port probe + HTTP banner.

import Foundation

// MARK: - Auth strategy hint
enum NetworkAuthHint {
    case smbOnly, sftpOnly, smbOrSftp, webUI, none
}

// MARK: - Fingerprint result
struct NetworkDeviceFingerprint {
    let deviceClass: NetworkDeviceClass
    let openPorts: Set<Int>
    let httpBanner: String?
}

// MARK: - Fingerprinter
enum NetworkDeviceFingerprinter {

    // MARK: - Known router/NAS keywords (hostname or HTTP banner)
    private static let routerKeywords = [
        "fritz", "fritzbox", "fritz-box", "router", "gateway",
        "speedport", "easybox", "dsl-router", "technicolor",
        "vodafone box", "o2 box", "192-168-178-1",
    ]
    private static let nasKeywords = [
        "synology", "qnap", "buffalo", "wd my cloud", "netgear",
        "readynas", "diskstation", "terramaster", "asustor",
    ]
    // Enigma2 / OpenPLi / Kodi media boxes — web UI only, no SMB shares
    private static let mediaBoxKeywords = [
        "vuduo", "vu+", "enigma", "openpli", "openatv", "openvix",
        "dreambox", "dm800", "dm900", "dm7080", "gigablue", "xtrend",
        "octagon", "edision", "formuler", "zgemma", "kodi", "libreelec",
        "openelec", "osmc", "batocera", "coreelec",
    ]

    // MARK: - Fast classification by Bonjour service set (no network IO)
    static func classifyByServices(_ serviceTypes: Set<String>) -> NetworkDeviceClass? {
        let types = serviceTypes.map { $0.lowercased() }

        // Mobile devices — _apple-mobdev2._tcp.
        if types.contains(where: { $0.contains("mobdev") }) {
            return .iPhone   // refined to iPad by name later
        }

        // Printers
        let printerTypes = ["_ipp._tcp.", "_ipps._tcp.", "_printer._tcp.",
                            "_pdl-datastream._tcp.", "_fax-ipp._tcp."]
        if !Set(types).isDisjoint(with: printerTypes) { return .printer }

        // Mac = SMB + SFTP (macOS always advertises both)
        let hasSMB  = types.contains { $0.contains("_smb._tcp.") }
        let hasSFTP = types.contains { $0.contains("_sftp-ssh._tcp.") }
        let hasFTP  = types.contains { $0.contains("_ftp._tcp.") }

        if hasSMB && hasSFTP  { return .mac }
        if (hasSFTP || hasFTP) && !hasSMB { return .linuxServer }
        // SMB-only is ambiguous — could be Mac, PC, NAS or fritz-box
        return nil
    }

    // MARK: - Name-based fast classification (before any probe)
    static func classifyByName(_ name: String, hostName: String) -> NetworkDeviceClass? {
        let n = name.lowercased()
        let h = hostName.lowercased()

        if routerKeywords.contains(where: { n.contains($0) || h.contains($0) }) { return .router }
        if mediaBoxKeywords.contains(where: { n.contains($0) || h.contains($0) }) { return .mediaBox }
        if nasKeywords.contains(where: { n.contains($0) || h.contains($0) }) { return .nas }

        // iPhone / iPad by name
        if n.contains("ipad") || h.contains("ipad") { return .iPad }
        if n.contains("iphone") || h.contains("iphone") || n.contains("s-iphone") { return .iPhone }
        // Mac by hostname pattern: kira-macpro, MacBook, iMac, mac-mini
        if n.contains("macpro") || n.contains("macbook") || n.contains("imac")
            || n.contains("mac-mini") || n.contains("macmini") { return .mac }
        // Windows PC — typical patterns
        if n.hasPrefix("sascha") || n.hasPrefix("pc-") || n.hasSuffix("-pc") { return .windowsPC }
        // UUID name (e.g. c51e7c78-e72c-48c8-...) — likely Smart TV / media device
        // UUID format: 8-4-4-4-12 hex chars separated by dashes
        let uuidParts = n.components(separatedBy: "-")
        if uuidParts.count == 5 && uuidParts[0].count == 8 && uuidParts[1].count == 4 {
            return .nas  // .nas = generic unknown device (shows NAS icon)
        }
        return nil
    }

    // MARK: - Full async probe (port scan + HTTP banner)
    static func probe(hostName: String, bonjourServices: Set<String>, name: String = "") async -> NetworkDeviceFingerprint {
        // Bonjour fast path
        if let quick = classifyByServices(bonjourServices) {
            return NetworkDeviceFingerprint(deviceClass: quick, openPorts: [], httpBanner: nil)
        }
        // Name fast path
        if let quick = classifyByName(name, hostName: hostName) {
            return NetworkDeviceFingerprint(deviceClass: quick, openPorts: [], httpBanner: nil)
        }

        let portsToCheck = [22, 80, 443, 445, 548, 21, 631]
        let openPorts = await probePortsConcurrently(host: hostName, ports: portsToCheck, timeout: 1.5)
        log.debug("[Fingerprint] \(hostName) open ports: \(openPorts.sorted())")
        let httpBanner = openPorts.contains(80) ? await fetchHTTPTitle(host: hostName) : nil
        if let banner = httpBanner {
            log.debug("[Fingerprint] \(hostName) HTTP title: \(banner)")
        }
        let deviceClass = classify(name: name, hostName: hostName, ports: openPorts, banner: httpBanner)
        return NetworkDeviceFingerprint(deviceClass: deviceClass, openPorts: openPorts, httpBanner: httpBanner)
    }

    // MARK: - Port-based classification
    private static func classify(name: String, hostName: String, ports: Set<Int>, banner: String?) -> NetworkDeviceClass {
        let n = name.lowercased()
        let h = hostName.lowercased()
        let bannerLower = banner?.lowercased() ?? ""

        if routerKeywords.contains(where: { bannerLower.contains($0) || n.contains($0) || h.contains($0) }) { return .router }
        // Enigma2 banner: contains "e2about", "openpli", "enigmaversion" etc.
        if mediaBoxKeywords.contains(where: { bannerLower.contains($0) || n.contains($0) || h.contains($0) })
            || bannerLower.contains("e2about") || bannerLower.contains("enigma") { return .mediaBox }
        if nasKeywords.contains(where: { bannerLower.contains($0) || n.contains($0) || h.contains($0) }) { return .nas }

        let has22  = ports.contains(22)
        let has80  = ports.contains(80)
        let has445 = ports.contains(445)
        let has548 = ports.contains(548)  // AFP — macOS only

        if has22 && has80 && has445 { return .nas }
        if has548 { return .mac }
        if has22 && has445 { return .mac }
        if has445 && !has22 { return .windowsPC }
        if has22 && !has445 { return .linuxServer }
        if has80 || ports.contains(443) { return .router }
        return .unknown
    }

    // MARK: - Concurrent port probe
    static func probePortsConcurrently(host: String, ports: [Int], timeout: TimeInterval) async -> Set<Int> {
        await withTaskGroup(of: Int?.self) { group in
            for port in ports {
                group.addTask { await isPortOpen(host: host, port: port, timeout: timeout) ? port : nil }
            }
            var open = Set<Int>()
            for await result in group { if let p = result { open.insert(p) } }
            return open
        }
    }

    // MARK: - TCP port check
    static func isPortOpen(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else { continuation.resume(returning: false); return }
                defer { close(sock) }
                var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
                var res: UnsafeMutablePointer<addrinfo>? = nil
                guard getaddrinfo(host, "\(port)", &hints, &res) == 0, let addr = res else {
                    continuation.resume(returning: false); return
                }
                defer { freeaddrinfo(res) }
                continuation.resume(returning: Darwin.connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0)
            }
        }
    }

    // MARK: - Fetch HTTP <title>
    static func fetchHTTPTitle(host: String) async -> String? {
        guard let url = URL(string: "http://\(host)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 2.5)
        req.httpMethod = "GET"
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        if let r = html.range(of: #"<title[^>]*>(.*?)</title>"#,
                               options: [.regularExpression, .caseInsensitive]) {
            return String(html[r])
                .replacingOccurrences(of: #"</?title[^>]*>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
