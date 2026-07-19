// MemoryDiagnostics.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Low-overhead memory checkpoints and sustained-growth detection.

import Darwin.Mach
import Foundation

// MARK: - Memory Snapshot
struct MemorySnapshot: Sendable {
    let residentBytes: UInt64
    let footprintBytes: UInt64
}

// MARK: - Memory Diagnostics
@MainActor
final class MemoryDiagnostics {
    static let shared = MemoryDiagnostics()
    private var timer: Timer?
    private var recentFootprints: [UInt64] = []
    private var lastSnapshot: MemorySnapshot?
    private let sampleLimit = 8
    private let growthWarningBytes: UInt64 = 64 * 1_024 * 1_024
    private let spikeWarningBytes: UInt64 = 256 * 1_024 * 1_024
    private let highFootprintBytes: UInt64 = 512 * 1_024 * 1_024

    private init() {}

    // MARK: - Monitoring
    func start() {
        guard timer == nil else { return }
        checkpoint("application.start")
        let timer = Timer(timeInterval: 60, target: self, selector: #selector(periodicCheckpoint), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Checkpoint
    func checkpoint(_ name: String) {
        let snapshot = Self.capture()
        let resident = Self.megabytes(snapshot.residentBytes)
        let footprint = Self.megabytes(snapshot.footprintBytes)
        let delta = lastSnapshot.map { Int64(snapshot.footprintBytes) - Int64($0.footprintBytes) } ?? 0
        log.info("[Memory] checkpoint=\(name) resident=\(resident)MB footprint=\(footprint)MB delta=\(Self.signedMegabytes(delta))MB")
        if delta >= Int64(spikeWarningBytes)
            || (snapshot.footprintBytes >= highFootprintBytes && lastSnapshot?.footprintBytes ?? 0 < highFootprintBytes)
        {
            log.warning(
                "[Memory] high allocation spike checkpoint=\(name) footprint=\(footprint)MB "
                    + "delta=\(Self.signedMegabytes(delta))MB; inspect active directory scans and previews"
            )
        }
        lastSnapshot = snapshot
        if name == "idle.periodic" { recordTrend(snapshot.footprintBytes, checkpoint: name) }
    }

    @objc private func periodicCheckpoint() {
        checkpoint("idle.periodic")
    }

    // MARK: - Trend Detection
    private func recordTrend(_ footprint: UInt64, checkpoint: String) {
        recentFootprints.append(footprint)
        if recentFootprints.count > sampleLimit { recentFootprints.removeFirst() }
        guard recentFootprints.count == sampleLimit,
            let first = recentFootprints.first,
            let last = recentFootprints.last
        else { return }
        let tolerance: UInt64 = 2 * 1_024 * 1_024
        let sustained = zip(recentFootprints, recentFootprints.dropFirst())
            .allSatisfy {
                previous, next in next + tolerance >= previous
            }
        guard sustained, last > first, last - first >= growthWarningBytes else { return }
        log.warning(
            "[Memory] possible sustained growth checkpoint=\(checkpoint) samples=\(sampleLimit) "
                + "increase=\(Self.megabytes(last - first))MB; capture an Instruments Allocations trace"
        )
    }

    // MARK: - Metrics
    nonisolated static func capture() -> MemorySnapshot {
        var basicInfo = mach_task_basic_info()
        var basicCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let basicResult = withUnsafeMutablePointer(to: &basicInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &basicCount)
            }
        }
        var vmInfo = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vmInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        let resident = basicResult == KERN_SUCCESS ? UInt64(basicInfo.resident_size) : 0
        let footprint = vmResult == KERN_SUCCESS ? UInt64(vmInfo.phys_footprint) : resident
        return MemorySnapshot(residentBytes: resident, footprintBytes: footprint)
    }

    nonisolated static func wholeMemoryLabel(bytes: UInt64) -> String {
        if bytes >= 1_024 * 1_024 { return "\(megabytes(bytes)) MB" }
        return "\(max(1, Int((bytes + 1_023) / 1_024))) KB"
    }

    nonisolated private static func megabytes(_ bytes: UInt64) -> Int {
        Int((bytes + 524_288) / 1_048_576)
    }

    nonisolated private static func signedMegabytes(_ bytes: Int64) -> Int {
        Int(bytes / 1_048_576)
    }
}
