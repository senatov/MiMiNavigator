// ResourceMonitorToolbarItem.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact live toolbar graphs for application memory and thread usage.

import AppKit
import Observation
import SwiftUI

// MARK: - Resource Monitor Model
@MainActor
@Observable
private final class ResourceMonitorModel {
    static let shared = ResourceMonitorModel()
    private(set) var memoryHistory: [Double] = []
    private(set) var threadHistory: [Double] = []
    private(set) var memoryLabel = "— MB"
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
        withAnimation(.easeInOut(duration: 0.35)) {
            memoryHistory = Self.appending(Double(memory.footprintBytes) / 1_048_576, to: memoryHistory)
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
                metric(title: "RAM", value: model.memoryLabel, history: model.memoryHistory, color: #colorLiteral(red: 0.176, green: 0.686, blue: 0.435, alpha: 1))
            }
            if showMemory && showThreads { Divider().frame(height: 26) }
            if showThreads {
                metric(title: "THR", value: model.threadLabel, history: model.threadHistory, color: #colorLiteral(red: 0.278, green: 0.518, blue: 0.941, alpha: 1))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
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
        if showMemory && showThreads { return "MiMiNavigator physical memory and live thread count" }
        return showMemory ? "MiMiNavigator physical memory" : "MiMiNavigator live thread count"
    }

    private var accessibilityText: String {
        if showMemory && showThreads { return "Memory \(model.memoryLabel), threads \(model.threadLabel)" }
        return showMemory ? "Memory \(model.memoryLabel)" : "Threads \(model.threadLabel)"
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
                    .frame(minWidth: title == "RAM" ? 42 : 20, alignment: .leading)
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
