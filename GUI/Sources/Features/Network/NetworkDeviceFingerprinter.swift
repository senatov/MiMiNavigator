// NetworkDeviceFingerprinter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Determines network device kind using Bonjour services, host naming,
//   port probing, and lightweight HTTP banner detection.
//   Classification priority: Bonjour services -> name keywords -> port+banner probe.

import Foundation

// MARK: - Auth strategy hint
enum NetworkAuthHint {
    case smbOnly, sftpOnly, smbOrSftp, webUI, none
}

// MARK: - Fingerprint result
struct NetworkDeviceFingerprint {
    let deviceClass: NetworkDeviceXT
    let openPorts: Set<Int>
    let httpBanner: String?
}

// MARK: - Fingerprinter
enum NetworkDeviceFingerprinter {

    // MARK: - Known router/NAS keywords (hostname or HTTP banner)
    private static let routerKeywords = [
        // Fritz!Box (AVM, Germany)
        "fritz", "fritzbox", "fritz-box", "192-168-178-1",
        // TP-Link
        "tplink", "tp-link", "archer", "deco",
        // Netgear
        "netgear", "nighthawk", "orbi",
        // D-Link
        "dlink", "d-link", "dir-",
        // Asus
        "asus", "rt-ac", "rt-ax", "rog rapture",
        // Linksys
        "linksys", "velop", "wrt",
        // Mikrotik
        "mikrotik", "routerboard",
        // Huawei
        "huawei", "honor router",
        // Generic
        "router", "gateway", "speedport", "easybox", "dsl-router",
        "technicolor", "vodafone box", "o2 box",
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

    private static let repeaterKeywords = [
        "repeater", "mesh repeater", "fritzrepeater", "range extender", "extender",
    ]
    private static let switchKeywords = [
        "switch", "netgear gs", "tp-link tl-sg", "unifi switch", "mikrotik css", "mikrotik crs",
    ]
    private static let smartTVKeywords = [
        "bravia", "smarttv", "smart-tv", "webos", "tizen", "aquos", "philips tv",
        "panasonic tv", "hisense", "sony tv", "lg tv", "samsung tv",
    ]
    private static let cameraKeywords = [
        "camera", "cam", "ipcam", "webcam", "hikvision", "dahua", "reolink", "foscam",
        "instar", "axis", "onvif",
    ]
    private static let gameConsoleKeywords = [
        "playstation", "ps4", "ps5", "xbox", "nintendo", "switch console", "steamdeck", "steam deck",
    ]
    private static let androidPhoneKeywords = [
        "galaxy", "pixel", "oneplus", "xiaomi", "redmi", "mi ", "oppo", "realme", "motorola",
    ]
    private static let androidTabletKeywords = [
        "tablet", "galaxy tab", "pixel tablet", "xiaomi pad", "lenovo tab",
    ]

    private static func containsAnyKeyword(_ keywords: [String], name: String, hostName: String, banner: String = "") -> Bool {
        keywords.contains { keyword in
            name.contains(keyword) || hostName.contains(keyword) || banner.contains(keyword)
        }
    }

    private static func isUUIDLikeName(_ value: String) -> Bool {
        let parts = value.components(separatedBy: "-")
        return parts.count == 5 && parts[0].count == 8 && parts[1].count == 4
    }

    private static func classifyAppleMobileDevice(name: String, hostName: String) -> NetworkDeviceXT? {
        if name.contains("ipad") || hostName.contains("ipad") {
            return .iPad
        }
        if name.contains("iphone") || hostName.contains("iphone") || name.contains("s-iphone") {
            return .iPhone
        }
        return nil
    }

    private static func classifyAndroidDevice(name: String, hostName: String) -> NetworkDeviceXT? {
        if containsAnyKeyword(androidTabletKeywords, name: name, hostName: hostName) {
            return .androidTablet
        }
        if containsAnyKeyword(androidPhoneKeywords, name: name, hostName: hostName) {
            return .androidPhone
        }
        return nil
    }

    private struct ServiceClassificationCandidate {
        let device: NetworkDeviceXT
        let score: Int
    }

    private static func serviceScore(_ lowercasedTypes: [String]) -> [ServiceClassificationCandidate] {
        let hasType: (String) -> Bool = { needle in
            lowercasedTypes.contains { $0.contains(needle) }
        }

        let hasSMB = hasType("_smb._tcp.")
        let hasSFTP = hasType("_sftp-ssh._tcp.")
        let hasFTP = hasType("_ftp._tcp.")
        let hasAirPlay = hasType("_airplay._tcp.")
        let hasGoogleCast = hasType("_googlecast._tcp.")
        let hasRAOP = hasType("_raop._tcp.")
        let hasUPnP = hasType("_upnp") || hasType("_media")
        let hasHTTP = hasType("_http._tcp.") || hasType("_https._tcp.")
        let hasPrinter = lowercasedTypes.contains {
            $0.contains("_ipp._tcp.")
                || $0.contains("_ipps._tcp.")
                || $0.contains("_printer._tcp.")
                || $0.contains("_pdl-datastream._tcp.")
                || $0.contains("_fax-ipp._tcp.")
        }
        let hasMobileService = lowercasedTypes.contains { $0.contains("mobdev") }

        var candidates: [ServiceClassificationCandidate] = []

        if hasMobileService {
            candidates.append(.init(device: .iPhone, score: 100))
        }
        if hasPrinter {
            candidates.append(.init(device: .printer, score: 100))
        }
        if hasSMB && hasSFTP {
            candidates.append(.init(device: .mac, score: 95))
        }
        if (hasSFTP || hasFTP) && !hasSMB {
            candidates.append(.init(device: .linuxServer, score: 90))
        }
        if hasAirPlay || hasGoogleCast || hasRAOP {
            candidates.append(.init(device: .mediaBox, score: 70))
        }
        if hasUPnP && hasHTTP {
            candidates.append(.init(device: .mediaBox, score: 55))
        }
        if hasHTTP {
            candidates.append(.init(device: .router, score: 20))
        }

        return candidates
    }

    private static func bestServiceClassification(from candidates: [ServiceClassificationCandidate]) -> NetworkDeviceXT? {
        candidates
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return String(describing: lhs.device) < String(describing: rhs.device)
                }
                return lhs.score > rhs.score
            }
            .first?
            .device
    }

    // MARK: - Fast classification by Bonjour service set (no network IO)
    static func classifyByServices(_ serviceTypes: Set<String>) -> NetworkDeviceXT? {
        let lowercasedTypes = serviceTypes.map { $0.lowercased() }
        let candidates = serviceScore(lowercasedTypes)
        return bestServiceClassification(from: candidates)
    }

    // MARK: - Name-based fast classification (before any probe)
    static func classifyByName(_ name: String, hostName: String) -> NetworkDeviceXT? {
        let lowercasedName = name.lowercased()
        let lowercasedHostName = hostName.lowercased()

        if containsAnyKeyword(routerKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .router
        }
        if containsAnyKeyword(repeaterKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .repeater
        }
        if containsAnyKeyword(switchKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .networkSwitch
        }
        if containsAnyKeyword(cameraKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .camera
        }
        if containsAnyKeyword(gameConsoleKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .gameConsole
        }
        if containsAnyKeyword(smartTVKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .smartTV
        }
        if containsAnyKeyword(mediaBoxKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .mediaBox
        }
        if containsAnyKeyword(nasKeywords, name: lowercasedName, hostName: lowercasedHostName) {
            return .nas
        }

        if let appleMobile = classifyAppleMobileDevice(name: lowercasedName, hostName: lowercasedHostName) {
            return appleMobile
        }
        if let androidDevice = classifyAndroidDevice(name: lowercasedName, hostName: lowercasedHostName) {
            return androidDevice
        }

        if lowercasedName.contains("macpro") || lowercasedName.contains("macbook") || lowercasedName.contains("imac")
            || lowercasedName.contains("mac-mini") || lowercasedName.contains("macmini") {
            return .mac
        }
        if lowercasedName.hasPrefix("sascha") || lowercasedName.hasPrefix("pc-") || lowercasedName.hasSuffix("-pc") {
            return .windowsPC
        }
        if isUUIDLikeName(lowercasedName) {
            return .mediaBox
        }

        return nil
    }

    // MARK: - Full async probe (port scan + HTTP banner)
    @concurrent static func probe(hostName: String, bonjourServices: Set<String>, name: String = "") async -> NetworkDeviceFingerprint {
        // Bonjour fast path
        if let quick = classifyByServices(bonjourServices) {
            return NetworkDeviceFingerprint(deviceClass: quick, openPorts: [], httpBanner: nil)
        }
        // Name fast path
        if let quick = classifyByName(name, hostName: hostName) {
            return NetworkDeviceFingerprint(deviceClass: quick, openPorts: [], httpBanner: nil)
        }

        let portsToCheck = [21, 22, 80, 443, 445, 548, 554, 631, 8008, 8009, 8080]
        let openPorts = await probePortsConcurrently(host: hostName, ports: portsToCheck, timeout: 1.5)
        log.debug("[Fingerprint] \(hostName) open ports: \(openPorts.sorted())")
        let shouldFetchHTTPBanner = openPorts.contains(80) || openPorts.contains(8080)
        let httpBanner = shouldFetchHTTPBanner ? await fetchHTTPTitle(host: hostName) : nil
        if let banner = httpBanner {
            log.debug("[Fingerprint] \(hostName) HTTP title: \(banner)")
        }
        let deviceClass = classify(name: name, hostName: hostName, ports: openPorts, banner: httpBanner)
        return NetworkDeviceFingerprint(deviceClass: deviceClass, openPorts: openPorts, httpBanner: httpBanner)
    }

    // MARK: - Port-based classification
    private static func classify(name: String, hostName: String, ports: Set<Int>, banner: String?) -> NetworkDeviceXT {
        let lowercasedName = name.lowercased()
        let lowercasedHostName = hostName.lowercased()
        let bannerLowercased = banner?.lowercased() ?? ""

        if containsAnyKeyword(routerKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .router
        }
        if containsAnyKeyword(repeaterKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .repeater
        }
        if containsAnyKeyword(switchKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .networkSwitch
        }
        if containsAnyKeyword(cameraKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased)
            || ports.contains(554) {
            return .camera
        }
        if containsAnyKeyword(gameConsoleKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .gameConsole
        }
        if containsAnyKeyword(smartTVKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .smartTV
        }
        if containsAnyKeyword(mediaBoxKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased)
            || bannerLowercased.contains("e2about")
            || bannerLowercased.contains("enigma") {
            return .mediaBox
        }
        if containsAnyKeyword(nasKeywords, name: lowercasedName, hostName: lowercasedHostName, banner: bannerLowercased) {
            return .nas
        }

        if let appleMobile = classifyAppleMobileDevice(name: lowercasedName, hostName: lowercasedHostName) {
            return appleMobile
        }
        if let androidDevice = classifyAndroidDevice(name: lowercasedName, hostName: lowercasedHostName) {
            return androidDevice
        }

        let hasSSH = ports.contains(22)
        let hasHTTP = ports.contains(80) || ports.contains(443) || ports.contains(8080)
        let hasSMB = ports.contains(445)
        let hasAFP = ports.contains(548)
        let hasFTP = ports.contains(21)
        let hasPrinter = ports.contains(631)
        let hasCast = ports.contains(8008) || ports.contains(8009)
        let hasRTSP = ports.contains(554)

        if hasPrinter {
            return .printer
        }
        if hasAFP {
            return .mac
        }
        if hasSSH && hasSMB {
            return .mac
        }
        if hasSSH && hasHTTP && hasSMB {
            return .nas
        }
        if hasSMB && !hasSSH {
            return .windowsPC
        }
        if hasSSH && !hasSMB {
            return .linuxServer
        }
        if hasRTSP {
            return .camera
        }
        if hasCast {
            return .mediaBox
        }
        if hasHTTP && hasFTP {
            return .router
        }
        if hasHTTP || hasFTP {
            return .unknown
        }

        return .unknown
    }

    // MARK: - Concurrent port probe
    @concurrent static func probePortsConcurrently(host: String, ports: [Int], timeout: TimeInterval) async -> Set<Int> {
        await withTaskGroup(of: Int?.self) { @concurrent group in
            for port in ports {
                group.addTask { @concurrent in await isPortOpen(host: host, port: port, timeout: timeout) ? port : nil }
            }
            var open = Set<Int>()
            for await result in group { if let p = result { open.insert(p) } }
            return open
        }
    }

    // MARK: - TCP port check
    @concurrent static func isPortOpen(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        // Skip obviously invalid hostnames (raw MAC addresses, empty, etc.)
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.isEmpty || h == "(nil)" || h.contains("@") { return false }
        // MAC address format (xx:xx:xx:xx:xx:xx) is not a valid hostname
        let octets = h.components(separatedBy: ":")
        if octets.count == 6 && octets.allSatisfy({ $0.count == 2 }) { return false }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else { continuation.resume(returning: false); return }
                defer { close(sock) }
                var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
                var res: UnsafeMutablePointer<addrinfo>? = nil
                let rc = getaddrinfo(h, "\(port)", &hints, &res)
                guard rc == 0, let addr = res else {
                    if res != nil { freeaddrinfo(res) }
                    continuation.resume(returning: false); return
                }
                defer { freeaddrinfo(res) }
                // Safety: verify ai_addr is not nil before calling connect
                guard addr.pointee.ai_addr != nil else {
                    continuation.resume(returning: false); return
                }
                continuation.resume(returning: Darwin.connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0)
            }
        }
    }

    // MARK: - Fetch HTTP <title>
    @concurrent static func fetchHTTPTitle(host: String) async -> String? {
        let candidates = [
            "https://\(host)",
            "http://\(host)",
            "http://\(host):8080",
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }

            var request = URLRequest(url: url, timeoutInterval: 2.5)
            request.httpMethod = "GET"

            guard let (data, _) = try? await URLSession.shared.data(for: request) else { continue }
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { continue }

            if let range = html.range(
                of: #"<title[^>]*>(.*?)</title>"#,
                options: [.regularExpression, .caseInsensitive]
            ) {
                let title = String(html[range])
                    .replacingOccurrences(of: #"</?title[^>]*>"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    return title
                }
            }

            if html.lowercased().contains("e2about") || html.lowercased().contains("enigmaversion") {
                return "Enigma2 Web UI"
            }
        }

        return nil
    }
}
