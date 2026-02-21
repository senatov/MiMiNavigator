// NetworkDeviceFingerprinter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Determines hardware type (Mac, PC, NAS, Router, Printer, Linux)
//              by probing open ports + HTTP banner + Bonjour service set.

import Foundation

// MARK: - Hardware device class
enum NetworkDeviceClass {
    case mac
    case windowsPC
    case linuxServer
    case nas
    case router
    case printer
    case unknown

    var systemIconName: String {
        switch self {
        case .mac:          return "desktopcomputer"
        case .windowsPC:    return "pc"
        case .linuxServer:  return "server.rack"
        case .nas:          return "externaldrive.connected.to.line.below"
        case .router:       return "wifi.router"
        case .printer:      return "printer"
        case .unknown:      return "network"
        }
    }

    var label: String {
        switch self {
        case .mac:          return "Mac"
        case .windowsPC:    return "PC"
        case .linuxServer:  return "Linux"
        case .nas:          return "NAS"
        case .router:       return "Router"
        case .printer:      return "Printer"
        case .unknown:      return ""
        }
    }

    var authHint: NetworkAuthHint {
        switch self {
        case .mac:          return .smbOrSftp
        case .windowsPC:    return .smbOnly
        case .linuxServer:  return .sftpOnly
        case .nas:          return .smbOrSftp
        case .router:       return .webUI
        case .printer:      return .none
        case .unknown:      return .smbOnly
        }
    }

    var isExpandable: Bool {
        switch self {
        case .printer, .router: return false
        default:                return true
        }
    }
}

// MARK: - Auth strategy hint
enum NetworkAuthHint {
    case smbOnly
    case sftpOnly
    case smbOrSftp
    case webUI
    case none
}

// MARK: - Fingerprint result
struct NetworkDeviceFingerprint {
    let deviceClass: NetworkDeviceClass
    let openPorts: Set<Int>
    let httpBanner: String?
}
// NetworkDeviceFingerprinter.swift (part 2 — probe logic)

import Foundation

// MARK: - Fingerprinter
enum NetworkDeviceFingerprinter {

    // MARK: - Bonjour-only fast classification (no network probe)
    static func classifyByServices(_ serviceTypes: Set<String>) -> NetworkDeviceClass? {
        let printerTypes: Set<String> = ["_ipp._tcp.", "_ipps._tcp.", "_printer._tcp.",
                                         "_pdl-datastream._tcp.", "_fax-ipp._tcp."]
        if !serviceTypes.isDisjoint(with: printerTypes) { return .printer }
        let hasSMB  = serviceTypes.contains { $0.contains("_smb._tcp.") }
        let hasSFTP = serviceTypes.contains { $0.contains("_sftp-ssh._tcp.") }
        let hasFTP  = serviceTypes.contains { $0.contains("_ftp._tcp.") }
        if hasSMB && hasSFTP  { return .mac }
        if hasSMB && !hasSFTP { return .windowsPC }
        if (hasSFTP || hasFTP) && !hasSMB { return .linuxServer }
        return nil
    }

    // MARK: - Full probe (async, port scan + HTTP banner)
    static func probe(hostName: String, bonjourServices: Set<String>) async -> NetworkDeviceFingerprint {
        if let quick = classifyByServices(bonjourServices) {
            return NetworkDeviceFingerprint(deviceClass: quick, openPorts: [], httpBanner: nil)
        }
        let portsToCheck = [22, 80, 443, 445, 548, 21, 631]
        let openPorts = await probePortsConcurrently(host: hostName, ports: portsToCheck, timeout: 1.5)
        log.debug("[Fingerprint] \(hostName) open ports: \(openPorts.sorted())")
        let httpBanner = openPorts.contains(80) ? await fetchHTTPTitle(host: hostName) : nil
        if let banner = httpBanner {
            log.debug("[Fingerprint] \(hostName) HTTP title: \(banner)")
        }
        let deviceClass = classify(hostName: hostName, ports: openPorts, banner: httpBanner)
        return NetworkDeviceFingerprint(deviceClass: deviceClass, openPorts: openPorts, httpBanner: httpBanner)
    }

    // MARK: - Classification logic
    private static func classify(hostName: String, ports: Set<Int>, banner: String?) -> NetworkDeviceClass {
        let name = hostName.lowercased()
        let bannerLower = banner?.lowercased() ?? ""
        let routerKeywords = ["fritz", "fritzbox", "router", "gateway", "speedport",
                              "easybox", "dsl-router", "technicolor", "vodafone box", "o2 box"]
        if routerKeywords.contains(where: { bannerLower.contains($0) || name.contains($0) }) { return .router }
        let nasKeywords = ["synology", "qnap", "buffalo", "wd my cloud", "netgear",
                           "readynas", "diskstation", "terramaster", "asustor"]
        if nasKeywords.contains(where: { bannerLower.contains($0) || name.contains($0) }) { return .nas }
        let has22 = ports.contains(22); let has445 = ports.contains(445)
        let has80 = ports.contains(80); let has548 = ports.contains(548)
        if has548 && has445  { return .mac }
        if has22  && has445  { return .mac }
        if has22  && has80 && has445 { return .nas }
        if has445 && !has22  { return .windowsPC }
        if has22  && !has445 { return .linuxServer }
        if has80  || ports.contains(443) { return .router }
        return .unknown
    }

    // MARK: - Concurrent port probe
    private static func probePortsConcurrently(host: String, ports: [Int], timeout: TimeInterval) async -> Set<Int> {
        await withTaskGroup(of: Int?.self) { group in
            for port in ports {
                group.addTask { await isPortOpen(host: host, port: port, timeout: timeout) ? port : nil }
            }
            var open = Set<Int>()
            for await result in group { if let p = result { open.insert(p) } }
            return open
        }
    }

    // MARK: - TCP port check via POSIX socket
    private static func isPortOpen(host: String, port: Int, timeout: TimeInterval) async -> Bool {
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
    private static func fetchHTTPTitle(host: String) async -> String? {
        guard let url = URL(string: "http://\(host)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 2.5)
        req.httpMethod = "GET"
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        if let r = html.range(of: #"<title[^>]*>(.*?)</title>"#, options: [.regularExpression, .caseInsensitive]) {
            return String(html[r])
                .replacingOccurrences(of: #"</?title[^>]*>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
