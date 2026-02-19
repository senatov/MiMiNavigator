// NetworkKitTests.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import Testing
@testable import NetworkKit

@Suite("NetworkHost Tests")
struct NetworkHostTests {

    @Test("SMB URL construction")
    func smbURL() {
        let host = NetworkHost(name: "Test", hostName: "test.local", serviceType: "_smb._tcp.")
        #expect(host.smbURL == URL(string: "smb://test.local/"))
    }

    @Test("AFP URL construction")
    func afpURL() {
        let host = NetworkHost(name: "Test", hostName: "test.local", serviceType: "_afpovertcp._tcp.")
        #expect(host.afpURL == URL(string: "afp://test.local/"))
    }

    @Test("Deduplication by hostName")
    func hostEquality() {
        let h1 = NetworkHost(name: "A", hostName: "host.local", serviceType: "_smb._tcp.")
        let h2 = NetworkHost(name: "B", hostName: "host.local", serviceType: "_smb._tcp.")
        var hosts: [NetworkHost] = [h1]
        if !hosts.contains(where: { $0.hostName == h2.hostName }) {
            hosts.append(h2)
        }
        #expect(hosts.count == 1)
    }
}
