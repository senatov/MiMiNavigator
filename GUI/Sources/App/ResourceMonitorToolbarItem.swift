// ResourceMonitorToolbarItem.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact live toolbar graphs for application memory and thread usage.

import AppKit
import Observation
import SwiftUI

// MARK: - Memory Graph Sample
struct MemoryGraphSample {
    let footprint: Double
    let compressed: Double

    var uncompressed: Double { max(footprint - compressed, 0) }
}

// MARK: - Resource Monitor Model
@MainActor
@Observable
private final class ResourceMonitorModel {
    static let shared = ResourceMonitorModel()
    private(set) var memoryHistory: [MemoryGraphSample] = []
    private(set) var threadHistory: [Double] = []
    private(set) var memoryLabel = "— MB"
    private(set) var compressedLabel = "0 MB"
    private(set) var threadLabel = "—"
    private var memoryTimer: Timer?
    private var threadTimer: Timer?
    private var activeMemoryInterval: TimeInterval?
    private var activeThreadInterval: TimeInterval?

    private init() {}

    // MARK: - Configure Independent Samplers
    func configure(memoryInterval: TimeInterval?, threadInterval: TimeInterval?) {
        if memoryInterval != activeMemoryInterval {
            memoryTimer?.invalidate()
            memoryTimer = nil
            activeMemoryInterval = memoryInterval
            if let memoryInterval {
                sampleMemory()
                let timer = Timer(timeInterval: memoryInterval, target: self, selector: #selector(sampleMemory), userInfo: nil, repeats: true)
                timer.tolerance = min(memoryInterval * 0.15, 1)
                RunLoop.main.add(timer, forMode: .common)
                memoryTimer = timer
            }
        }
        if threadInterval != activeThreadInterval {
            threadTimer?.invalidate()
            threadTimer = nil
            activeThreadInterval = threadInterval
            if let threadInterval {
                sampleThreads()
                let timer = Timer(timeInterval: threadInterval, target: self, selector: #selector(sampleThreads), userInfo: nil, repeats: true)
                timer.tolerance = min(threadInterval * 0.15, 1)
                RunLoop.main.add(timer, forMode: .common)
                threadTimer = timer
            }
        }
    }

    // MARK: - Sample Memory
    @objc private func sampleMemory() {
        let memory = MemoryDiagnostics.captureMemory()
        guard memory.footprintBytes > 0 else { return }
        memoryLabel = MemoryDiagnostics.wholeMemoryLabel(bytes: memory.footprintBytes)
        let compressedBytes = min(memory.compressedBytes, memory.footprintBytes)
        compressedLabel = compressedBytes == 0 ? "0 MB" : MemoryDiagnostics.wholeMemoryLabel(bytes: compressedBytes)
        let sample = MemoryGraphSample(
            footprint: Double(memory.footprintBytes) / 1_048_576,
            compressed: Double(compressedBytes) / 1_048_576
        )
        memoryHistory = Array((memoryHistory + [sample]).suffix(24))
    }

    // MARK: - Sample Threads
    @objc private func sampleThreads() {
        let threadCount = MemoryDiagnostics.captureThreadCount()
        guard threadCount > 0 else { return }
        threadLabel = "\(threadCount)"
        threadHistory = Array((threadHistory + [Double(threadCount)]).suffix(24))
    }

    // MARK: - Stop Samplers
    func stop() {
        memoryTimer?.invalidate()
        threadTimer?.invalidate()
        memoryTimer = nil
        threadTimer = nil
        activeMemoryInterval = nil
        activeThreadInterval = nil
    }
}

// MARK: - Resource Monitor Toolbar Item
struct ResourceMonitorToolbarItem: View {
    let showMemory: Bool
    let showThreads: Bool
    let memoryInterval: TimeInterval
    let threadsInterval: TimeInterval
    @State private var model = ResourceMonitorModel.shared

    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            if showMemory {
                metric(title: "MEMORY", value: model.memoryLabel, tint: Color(#colorLiteral(red: 0.10, green: 0.52, blue: 0.78, alpha: 1))) {
                    MemoryResourceChart(samples: model.memoryHistory)
                }
            }
            if showMemory && showThreads { Rectangle().fill(.primary.opacity(0.12)).frame(width: 1, height: 22) }
            if showThreads {
                metric(title: "THREADS", value: model.threadLabel, tint: Color(#colorLiteral(red: 0.30, green: 0.46, blue: 0.75, alpha: 1))) {
                    ThreadResourceChart(values: model.threadHistory)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: TopToolbarMetrics.height)
        .background { TopToolbarSurface() }
        .fixedSize()
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear { configureSamplers() }
        .onChange(of: showMemory) { _, _ in configureSamplers() }
        .onChange(of: showThreads) { _, _ in configureSamplers() }
        .onChange(of: memoryInterval) { _, _ in configureSamplers() }
        .onChange(of: threadsInterval) { _, _ in configureSamplers() }
        .onDisappear { model.stop() }
    }

    private var helpText: String {
        if showMemory && showThreads { return "MiMiNavigator footprint \(model.memoryLabel), compressed \(model.compressedLabel); \(model.threadLabel) threads" }
        return showMemory ? "MiMiNavigator footprint \(model.memoryLabel), compressed \(model.compressedLabel)" : "MiMiNavigator threads \(model.threadLabel)"
    }

    private var accessibilityText: String {
        if showMemory && showThreads { return "Memory footprint \(model.memoryLabel), compressed \(model.compressedLabel), threads \(model.threadLabel)" }
        return showMemory ? "Memory footprint \(model.memoryLabel), compressed \(model.compressedLabel)" : "Threads \(model.threadLabel)"
    }

    // MARK: - Metric
    private func metric<Chart: View>(title: String, value: String, tint: Color, @ViewBuilder chart: () -> Chart) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize()
            }
            chart()
                .frame(width: 62, height: 22)
        }
    }

    // MARK: - Configure Samplers
    private func configureSamplers() {
        model.configure(
            memoryInterval: showMemory ? memoryInterval : nil,
            threadInterval: showThreads ? threadsInterval : nil
        )
    }
}
