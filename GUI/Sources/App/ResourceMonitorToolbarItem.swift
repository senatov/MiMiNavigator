// ResourceMonitorToolbarItem.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact live toolbar graphs for application memory and thread usage.

import AppKit
import Observation
import SwiftUI

// MARK: - Memory Graph Sample
private struct MemoryGraphSample {
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
        memoryLabel = MemoryDiagnostics.wholeMemoryLabel(bytes: memory.footprintBytes)
        let compressedBytes = min(memory.compressedBytes, memory.footprintBytes)
        compressedLabel = compressedBytes == 0 ? "0 MB" : MemoryDiagnostics.wholeMemoryLabel(bytes: compressedBytes)
        withAnimation(.easeInOut(duration: 0.35)) {
            let sample = MemoryGraphSample(
                footprint: Double(memory.footprintBytes) / 1_048_576,
                compressed: Double(compressedBytes) / 1_048_576
            )
            memoryHistory = memoryHistory.isEmpty
                ? Array(repeating: sample, count: 24)
                : Array((memoryHistory + [sample]).suffix(24))
        }
    }

    // MARK: - Sample Threads
    @objc private func sampleThreads() {
        let threadCount = MemoryDiagnostics.captureThreadCount()
        threadLabel = threadCount > 0 ? "\(threadCount)" : "—"
        withAnimation(.easeInOut(duration: 0.35)) {
            threadHistory = Self.appending(Double(threadCount), to: threadHistory)
        }
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

    // MARK: - Rolling History
    private static func appending(_ value: Double, to history: [Double]) -> [Double] {
        Array((history + [value]).suffix(24))
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
        HStack(spacing: 7) {
            if showMemory {
                memoryMetric
            }
            if showMemory && showThreads { Divider().frame(height: 26) }
            if showThreads {
                metric(title: "THR", value: model.threadLabel, history: model.threadHistory, color: #colorLiteral(red: 0.278, green: 0.518, blue: 0.941, alpha: 1))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
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
        if showMemory && showThreads { return "MiMiNavigator memory footprint \(model.memoryLabel), compressed \(model.compressedLabel); live thread count" }
        return showMemory ? "MiMiNavigator memory footprint \(model.memoryLabel), compressed \(model.compressedLabel)" : "MiMiNavigator live thread count"
    }

    private var accessibilityText: String {
        if showMemory && showThreads { return "Memory footprint \(model.memoryLabel), compressed \(model.compressedLabel), threads \(model.threadLabel)" }
        return showMemory ? "Memory footprint \(model.memoryLabel), compressed \(model.compressedLabel)" : "Threads \(model.threadLabel)"
    }

    // MARK: - Memory Metric
    private var memoryMetric: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text("MEM")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                Text(model.memoryLabel)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)
                    .frame(minWidth: 42, alignment: .leading)
            }
            StackedMemorySparkline(samples: model.memoryHistory)
                .frame(width: 34, height: 24)
        }
    }

    // MARK: - Metric
    private func metric(title: String, value: String, history: [Double], color: NSColor) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)
                    .frame(minWidth: 20, alignment: .leading)
            }
            ResourceSparkline(values: history, color: Color(nsColor: color))
                .frame(width: 34, height: 24)
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

// MARK: - Stacked Memory Sparkline
private struct StackedMemorySparkline: View {
    let samples: [MemoryGraphSample]
    private let activeColor = Color(#colorLiteral(red: 0.553, green: 0.788, blue: 0.949, alpha: 1))
    private let compressedColor = Color(#colorLiteral(red: 0.969, green: 0.847, blue: 0.490, alpha: 1))
    private let activeBorderColor = Color(#colorLiteral(red: 0.278, green: 0.518, blue: 0.741, alpha: 1))
    private let compressedBorderColor = Color(#colorLiteral(red: 0.710, green: 0.549, blue: 0.176, alpha: 1))

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let maximum = max(samples.map(\.footprint).max() ?? 0, 1) * 1.5
            let baseline = size.height
            let scale = size.height / CGFloat(maximum)
            let blue = areaPath(in: size, baseline: baseline, scale: scale, upper: \.uncompressed, lower: { _ in 0 })
            let yellow = areaPath(in: size, baseline: baseline, scale: scale, upper: \.footprint, lower: \.uncompressed)
            context.fill(blue, with: .color(activeColor))
            context.fill(yellow, with: .color(compressedColor))
            let borderStyle = StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
            context.stroke(linePath(in: size, baseline: baseline, scale: scale, value: \.uncompressed), with: .color(activeBorderColor), style: borderStyle)
            if samples.contains(where: { $0.compressed > 0 }) {
                context.stroke(linePath(in: size, baseline: baseline, scale: scale, value: \.footprint), with: .color(compressedBorderColor), style: borderStyle)
            }
        }
    }

    // MARK: - Layer Boundary
    private func linePath(in size: CGSize, baseline: CGFloat, scale: CGFloat, value: KeyPath<MemoryGraphSample, Double>) -> Path {
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(samples.count - 1), y: baseline - CGFloat(sample[keyPath: value]) * scale)
            if index == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        return path
    }

    // MARK: - Area Path
    private func areaPath(
        in size: CGSize,
        baseline: CGFloat,
        scale: CGFloat,
        upper: KeyPath<MemoryGraphSample, Double>,
        lower: (MemoryGraphSample) -> Double
    ) -> Path {
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(samples.count - 1), y: baseline - CGFloat(sample[keyPath: upper]) * scale)
            if index == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        for index in samples.indices.reversed() {
            let sample = samples[index]
            let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(samples.count - 1), y: baseline - CGFloat(lower(sample)) * scale)
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Resource Sparkline
/// Adapted from Hop's MIT-licensed compact Sparkline view by Anton Shakirov.
private struct ResourceSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let span = max(high - low, 0.0001)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - CGFloat((value - low) / span)) * 0.8 + size.height * 0.1
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    }
}
